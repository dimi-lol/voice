#!/bin/bash

# Script para testar configuração em Português Brasileiro
echo "🇧🇷 Testando configuração em Português Brasileiro"
echo ""

# Verificar se os arquivos foram configurados corretamente
echo "🔍 Verificando configurações..."

# 1. Verificar server.py
echo "📁 Verificando server.py..."
if grep -q 'LANGUAGE.*=.*os.getenv.*"pt"' code/server.py; then
    echo "✅ server.py: LANGUAGE configurado para PT"
else
    echo "❌ server.py: LANGUAGE não configurado para PT"
fi

# 2. Verificar transcribe.py
echo "📁 Verificando transcribe.py..."
if grep -q 'source_language.*=.*"pt"' code/transcribe.py; then
    echo "✅ transcribe.py: source_language configurado para PT"
else
    echo "❌ transcribe.py: source_language não configurado para PT"
fi

if grep -q '"language".*:.*"pt"' code/transcribe.py; then
    echo "✅ transcribe.py: default language configurado para PT"
else
    echo "❌ transcribe.py: default language não configurado para PT"
fi

if grep -q '"model".*:.*"base"' code/transcribe.py && grep -q '"realtime_model_type".*:.*"base"' code/transcribe.py; then
    echo "✅ transcribe.py: modelos Whisper multilíngues configurados"
else
    echo "❌ transcribe.py: modelos Whisper ainda em inglês"
fi

# 3. Verificar audio_in.py
echo "📁 Verificando audio_in.py..."
if grep -q 'language.*=.*"pt"' code/audio_in.py; then
    echo "✅ audio_in.py: language configurado para PT"
else
    echo "❌ audio_in.py: language não configurado para PT"
fi

# 4. Verificar docker-compose.yml
echo "📁 Verificando docker-compose.yml..."
if grep -q 'LANGUAGE=pt' docker-compose.yml; then
    echo "✅ docker-compose.yml: LANGUAGE=pt configurado"
else
    echo "❌ docker-compose.yml: LANGUAGE=pt não configurado"
fi

# 5. Verificar config.env.example
echo "📁 Verificando config.env.example..."
if grep -q 'LANGUAGE=pt' config.env.example; then
    echo "✅ config.env.example: LANGUAGE=pt configurado"
else
    echo "❌ config.env.example: LANGUAGE=pt não configurado"
fi

# 6. Verificar se o modelo Orpheus está presente
echo "📁 Verificando modelo Orpheus BR-Speech..."
if [ -d "models/orpheus-brspeech-3b-0.1-ft-32bits-GGUF" ]; then
    echo "✅ Modelo Orpheus BR-Speech encontrado"
    echo "   📊 Tamanho: $(du -sh models/orpheus-brspeech-3b-0.1-ft-32bits-GGUF 2>/dev/null | cut -f1 || echo 'N/A')"
else
    echo "⚠️  Modelo Orpheus BR-Speech não encontrado"
    echo "   💡 Execute: ./download-orpheus-model.sh"
fi

echo ""
echo "📋 Resumo da Configuração PT-BR:"

# Contar sucessos
success_count=0
total_checks=6

if grep -q 'LANGUAGE.*=.*os.getenv.*"pt"' code/server.py; then ((success_count++)); fi
if grep -q 'source_language.*=.*"pt"' code/transcribe.py; then ((success_count++)); fi
if grep -q 'language.*=.*"pt"' code/audio_in.py; then ((success_count++)); fi
if grep -q 'LANGUAGE=pt' docker-compose.yml; then ((success_count++)); fi
if grep -q 'LANGUAGE=pt' config.env.example; then ((success_count++)); fi
if [ -d "models/orpheus-brspeech-3b-0.1-ft-32bits-GGUF" ]; then ((success_count++)); fi

echo "✅ Configurações corretas: $success_count/$total_checks"

if [ $success_count -eq $total_checks ]; then
    echo ""
    echo "🎉 Tudo configurado para Português Brasileiro!"
    echo ""
    echo "🚀 Próximos passos:"
    echo "   1. Execute: ./start-dev.sh ou ./start-docker.sh"
    echo "   2. Acesse: http://localhost:3000"
    echo "   3. Teste falando em português brasileiro"
    echo ""
    echo "🎙️ Pipeline PT-BR:"
    echo "   Fala (PT) → Whisper → LLM → Orpheus BR → Áudio (PT)"
else
    echo ""
    echo "⚠️  Algumas configurações precisam ser ajustadas."
    echo "   📚 Consulte: CHANGELOG-PTBR.md"
fi

echo ""
echo "📊 Modelos em uso:"
echo "   🔤 Speech-to-Text: Whisper Base (multilíngue)"
echo "   🔊 Text-to-Speech: Orpheus BR-Speech 3B"
echo "   🎯 Idioma: Português Brasileiro (pt)" 