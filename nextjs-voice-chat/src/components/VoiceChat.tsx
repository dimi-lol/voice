'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Play, Square, RotateCcw, Copy, Mic, MicOff } from 'lucide-react'

interface Message {
  role: 'user' | 'assistant'
  content: string
  type?: 'final' | 'partial'
}

const VoiceChat = () => {
  const [messages, setMessages] = useState<Message[]>([])
  const [isConnected, setIsConnected] = useState(false)
  const [status, setStatus] = useState('Ready to chat')
  const [typingUser, setTypingUser] = useState('')
  const [typingAssistant, setTypingAssistant] = useState('')
  const [speed, setSpeed] = useState(0)
  const [isTTSPlaying, setIsTTSPlaying] = useState(false)
  const [ignoreIncomingTTS, setIgnoreIncomingTTS] = useState(false)

  const socketRef = useRef<WebSocket | null>(null)
  const audioContextRef = useRef<AudioContext | null>(null)
  const mediaStreamRef = useRef<MediaStream | null>(null)
  const micWorkletNodeRef = useRef<AudioWorkletNode | null>(null)
  const ttsWorkletNodeRef = useRef<AudioWorkletNode | null>(null)
  const messagesEndRef = useRef<HTMLDivElement>(null)

  // Batching setup
  const BATCH_SAMPLES = 2048
  const HEADER_BYTES = 8
  const FRAME_BYTES = BATCH_SAMPLES * 2
  const MESSAGE_BYTES = HEADER_BYTES + FRAME_BYTES

  const bufferPoolRef = useRef<ArrayBuffer[]>([])
  const batchBufferRef = useRef<ArrayBuffer | null>(null)
  const batchViewRef = useRef<DataView | null>(null)
  const batchInt16Ref = useRef<Int16Array | null>(null)
  const batchOffsetRef = useRef(0)

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  useEffect(() => {
    scrollToBottom()
  }, [messages, typingUser, typingAssistant])

  const initBatch = () => {
    if (!batchBufferRef.current) {
      batchBufferRef.current = bufferPoolRef.current.pop() || new ArrayBuffer(MESSAGE_BYTES)
      batchViewRef.current = new DataView(batchBufferRef.current)
      batchInt16Ref.current = new Int16Array(batchBufferRef.current, HEADER_BYTES)
      batchOffsetRef.current = 0
    }
  }

  const flushBatch = () => {
    if (!batchBufferRef.current || !batchViewRef.current || !socketRef.current) return

    const ts = Date.now() & 0xFFFFFFFF
    batchViewRef.current.setUint32(0, ts, false)
    const flags = isTTSPlaying ? 1 : 0
    batchViewRef.current.setUint32(4, flags, false)

    socketRef.current.send(batchBufferRef.current)

    bufferPoolRef.current.push(batchBufferRef.current)
    batchBufferRef.current = null
  }

  const flushRemainder = () => {
    if (batchOffsetRef.current > 0 && batchInt16Ref.current) {
      for (let i = batchOffsetRef.current; i < BATCH_SAMPLES; i++) {
        batchInt16Ref.current[i] = 0
      }
      flushBatch()
    }
  }

  const base64ToInt16Array = (b64: string): Int16Array => {
    const raw = atob(b64)
    const buf = new ArrayBuffer(raw.length)
    const view = new Uint8Array(buf)
    for (let i = 0; i < raw.length; i++) {
      view[i] = raw.charCodeAt(i)
    }
    return new Int16Array(buf)
  }

  const initAudioContext = async () => {
    if (!audioContextRef.current) {
      audioContextRef.current = new AudioContext()
    }
    if (audioContextRef.current.state === 'suspended') {
      await audioContextRef.current.resume()
    }
  }

  const startRawPcmCapture = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        audio: {
          sampleRate: { ideal: 24000 },
          channelCount: 1,
          echoCancellation: true,
          noiseSuppression: true
        }
      })

      mediaStreamRef.current = stream
      await initAudioContext()

      if (!audioContextRef.current) return

      // Load PCM processor
      await audioContextRef.current.audioWorklet.addModule('/pcmWorkletProcessor.js')
      micWorkletNodeRef.current = new AudioWorkletNode(audioContextRef.current, 'pcm-worklet-processor')

      micWorkletNodeRef.current.port.onmessage = ({ data }) => {
        const incoming = new Int16Array(data)
        let read = 0

        while (read < incoming.length) {
          initBatch()
          if (!batchInt16Ref.current) return

          const toCopy = Math.min(
            incoming.length - read,
            BATCH_SAMPLES - batchOffsetRef.current
          )

          batchInt16Ref.current.set(
            incoming.subarray(read, read + toCopy),
            batchOffsetRef.current
          )

          batchOffsetRef.current += toCopy
          read += toCopy

          if (batchOffsetRef.current === BATCH_SAMPLES) {
            flushBatch()
          }
        }
      }

      const source = audioContextRef.current.createMediaStreamSource(stream)
      source.connect(micWorkletNodeRef.current)
      setStatus('🎤 Listening...')

    } catch (err) {
      setStatus('❌ Microphone access denied')
      console.error(err)
    }
  }

  const setupTTSPlayback = async () => {
    if (!audioContextRef.current) return

    await audioContextRef.current.audioWorklet.addModule('/ttsPlaybackProcessor.js')
    ttsWorkletNodeRef.current = new AudioWorkletNode(
      audioContextRef.current,
      'tts-playback-processor'
    )

    ttsWorkletNodeRef.current.port.onmessage = (event) => {
      const { type } = event.data
      if (type === 'ttsPlaybackStarted') {
        if (!isTTSPlaying && socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
          setIsTTSPlaying(true)
          console.log('TTS playback started')
          socketRef.current.send(JSON.stringify({ type: 'tts_start' }))
        }
      } else if (type === 'ttsPlaybackStopped') {
        if (isTTSPlaying && socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
          setIsTTSPlaying(false)
          console.log('TTS playback stopped')
          socketRef.current.send(JSON.stringify({ type: 'tts_stop' }))
        }
      }
    }

    ttsWorkletNodeRef.current.connect(audioContextRef.current.destination)
  }

  const cleanupAudio = () => {
    if (micWorkletNodeRef.current) {
      micWorkletNodeRef.current.disconnect()
      micWorkletNodeRef.current = null
    }
    if (ttsWorkletNodeRef.current) {
      ttsWorkletNodeRef.current.disconnect()
      ttsWorkletNodeRef.current = null
    }
    if (audioContextRef.current) {
      audioContextRef.current.close()
      audioContextRef.current = null
    }
    if (mediaStreamRef.current) {
      mediaStreamRef.current.getAudioTracks().forEach(track => track.stop())
      mediaStreamRef.current = null
    }
  }

  const handleJSONMessage = useCallback((message: any) => {
    const { type, content } = message

    switch (type) {
      case 'partial_user_request':
        setTypingUser(content?.trim() ? content : '')
        break

      case 'final_user_request':
        if (content?.trim()) {
          setMessages(prev => [...prev, { role: 'user', content, type: 'final' }])
        }
        setTypingUser('')
        break

      case 'partial_assistant_answer':
        setTypingAssistant(content?.trim() ? content : '')
        break

      case 'final_assistant_answer':
        if (content?.trim()) {
          setMessages(prev => [...prev, { role: 'assistant', content, type: 'final' }])
        }
        setTypingAssistant('')
        break

      case 'tts_chunk':
        if (ignoreIncomingTTS) return
        const int16Data = base64ToInt16Array(content)
        if (ttsWorkletNodeRef.current) {
          ttsWorkletNodeRef.current.port.postMessage(int16Data)
        }
        break

      case 'tts_interruption':
        if (ttsWorkletNodeRef.current) {
          ttsWorkletNodeRef.current.port.postMessage({ type: 'clear' })
        }
        setIsTTSPlaying(false)
        setIgnoreIncomingTTS(false)
        break

      case 'stop_tts':
        if (ttsWorkletNodeRef.current) {
          ttsWorkletNodeRef.current.port.postMessage({ type: 'clear' })
        }
        setIsTTSPlaying(false)
        setIgnoreIncomingTTS(true)
        console.log('TTS playback stopped')
        if (socketRef.current) {
          socketRef.current.send(JSON.stringify({ type: 'tts_stop' }))
        }
        break
    }
  }, [ignoreIncomingTTS, isTTSPlaying])

  const startConnection = async () => {
    if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
      setStatus('✅ Already listening!')
      return
    }

    setStatus('🔄 Connecting...')

    const wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    // Conectar ao backend Python que estará rodando na porta 8000
    const wsUrl = process.env.NODE_ENV === 'production'
      ? `${wsProto}//backend:8000/ws`
      : `${wsProto}//localhost:8000/ws`

    socketRef.current = new WebSocket(wsUrl)

    socketRef.current.onopen = async () => {
      setStatus('🔊 Activating microphone and audio...')
      setIsConnected(true)
      await startRawPcmCapture()
      await setupTTSPlayback()
    }

    socketRef.current.onmessage = (evt) => {
      if (typeof evt.data === 'string') {
        try {
          const msg = JSON.parse(evt.data)
          handleJSONMessage(msg)
        } catch (e) {
          console.error('Error processing message:', e)
        }
      }
    }

    socketRef.current.onclose = () => {
      setStatus('❌ Connection closed')
      setIsConnected(false)
      flushRemainder()
      cleanupAudio()
    }

    socketRef.current.onerror = (err) => {
      setStatus('⚠️ Connection error')
      setIsConnected(false)
      cleanupAudio()
      console.error(err)
    }
  }

  const stopConnection = () => {
    if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
      flushRemainder()
      socketRef.current.close()
    }
    cleanupAudio()
    setStatus('⏹️ Conversation paused')
    setIsConnected(false)
  }

  const clearConversation = () => {
    setMessages([])
    setTypingUser('')
    setTypingAssistant('')
    if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
      socketRef.current.send(JSON.stringify({ type: 'clear_history' }))
    }
  }

  const copyConversation = () => {
    const text = messages
      .map(msg => `${msg.role === 'user' ? 'You' : 'Co-Human'}: ${msg.content}`)
      .join('\n')

    navigator.clipboard.writeText(text)
      .then(() => {
        console.log('Conversation copied!')
      })
      .catch(err => console.error('Copy failed:', err))
  }

  const handleSpeedChange = (newSpeed: number) => {
    setSpeed(newSpeed)
    if (socketRef.current && socketRef.current.readyState === WebSocket.OPEN) {
      socketRef.current.send(JSON.stringify({
        type: 'set_speed',
        speed: newSpeed
      }))
    }
  }

  useEffect(() => {
    return () => {
      cleanupAudio()
      if (socketRef.current) {
        socketRef.current.close()
      }
    }
  }, [])

  return (
    <div className="flex items-center justify-center min-h-screen p-5">
      <div className="flex-1 max-w-2xl w-full bg-white/95 backdrop-blur-2xl shadow-2xl border border-white/20 rounded-3xl flex flex-col overflow-hidden max-h-[90vh]">
        {/* Header */}
        <div className="bg-gradient-to-r from-blue-600 to-purple-600 text-white p-6 flex items-center gap-3">
          <div className="w-8 h-8 bg-white/20 rounded-full flex items-center justify-center text-sm font-bold">
            🤖
          </div>
          <h1 className="text-xl font-semibold">Co-Human - AI Assistant 🇧🇷</h1>
          <span className="ml-auto text-sm opacity-90">{status}</span>
        </div>

        {/* Messages */}
        <div className="flex-1 p-6 overflow-y-auto bg-white/10 space-y-4">
          {messages.length === 0 && !typingUser && !typingAssistant ? (
            <div className="text-center py-10 text-gray-600">
              <h2 className="text-2xl font-semibold text-blue-600 mb-3">Olá! Sou seu Co-Human 👋🇧🇷</h2>
              <p className="text-lg mb-2">Clique em <strong>Start</strong> para começar nossa conversa por voz!</p>
              <p className="text-lg">Estou aqui para ajudar com tudo que você precisar.</p>
              <p className="text-sm text-blue-500 mt-3">✨ Powered by Orpheus BR-Speech</p>
            </div>
          ) : (
            <>
              {messages.map((msg, index) => (
                <div
                  key={index}
                  className={`max-w-[85%] p-4 rounded-2xl shadow-lg font-medium ${msg.role === 'user'
                    ? 'bg-gradient-to-r from-blue-600 to-purple-600 text-white ml-auto rounded-br-md'
                    : 'bg-gradient-to-r from-pink-500 to-red-500 text-white mr-auto rounded-bl-md'
                    }`}
                >
                  {msg.content}
                </div>
              ))}

              {typingUser && (
                <div className="max-w-[85%] p-4 rounded-2xl bg-gradient-to-r from-blue-600 to-purple-600 text-white ml-auto rounded-br-md animate-pulse">
                  {typingUser} <span className="opacity-60">✏️</span>
                </div>
              )}

              {typingAssistant && (
                <div className="max-w-[85%] p-4 rounded-2xl bg-gradient-to-r from-pink-500 to-red-500 text-white mr-auto rounded-bl-md animate-pulse">
                  {typingAssistant} <span className="opacity-60">✏️</span>
                </div>
              )}
            </>
          )}
          <div ref={messagesEndRef} />
        </div>

        {/* Controls */}
        <div className="p-6 bg-white/95 backdrop-blur-lg border-t border-white/20 space-y-4">
          {/* Speed Control */}
          <div className="flex-1">
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Response Speed
            </label>
            <input
              type="range"
              min="0"
              max="100"
              value={speed}
              onChange={(e) => handleSpeedChange(parseInt(e.target.value))}
              disabled={!isConnected}
              className="w-full h-2 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg appearance-none cursor-pointer slider"
            />
            <div className="flex justify-between mt-2 text-xs text-gray-500 font-medium">
              <span>Fast</span>
              <span>Slow</span>
            </div>
          </div>

          {/* Buttons */}
          <div className="flex gap-3 flex-wrap">
            <button
              onClick={startConnection}
              disabled={isConnected}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-blue-500 to-cyan-500 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-1 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Play size={20} />
            </button>

            <button
              onClick={stopConnection}
              disabled={!isConnected}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-pink-500 to-yellow-400 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-1 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <Square size={20} />
            </button>

            <button
              onClick={clearConversation}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-teal-400 to-pink-300 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-1 transition-all duration-300"
            >
              <RotateCcw size={20} />
            </button>

            <button
              onClick={copyConversation}
              className="flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-semibold rounded-xl shadow-lg hover:shadow-xl hover:-translate-y-1 transition-all duration-300"
            >
              <Copy size={20} />
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}

export default VoiceChat 