# Voice Chat - Frontend + Backend Separados

Este projeto foi reestruturado para separar o frontend (NextJS) do backend (FastAPI + Python), permitindo maior escalabilidade e facilidade de desenvolvimento.

## 🏗️ Arquitetura

- **Frontend**: NextJS 14 com TypeScript, Tailwind CSS e WebRTC
- **Backend**: FastAPI com Python para processamento de voz e IA
- **Comunicação**: WebSocket para streaming de áudio em tempo real
- **Containerização**: Docker Compose orquestrando ambos os serviços

## 🚀 Executando com Docker Compose

### Pré-requisitos
- Docker e Docker Compose instalados
- GPU NVIDIA (opcional, para melhor performance de IA)

### Executar o projeto completo
```bash
# 1. Setup inicial (incluindo download do modelo)
./setup.sh

# 2. Ou baixar apenas o modelo Orpheus BR-Speech
./download-orpheus-model.sh

# 3. Construir e executar ambos os serviços
docker-compose up --build

# Executar em background
docker-compose up -d --build

# Ver logs em tempo real
docker-compose logs -f

# Parar os serviços
docker-compose down
```

### Acessar os serviços
- **Frontend**: http://localhost:3000
- **Backend API**: http://localhost:8000
- **Health Checks**: 
  - Frontend: http://localhost:3000/api/health
  - Backend: http://localhost:8000/health

## 🛠️ Desenvolvimento Local

### Backend (Python/FastAPI)
```bash
# Entrar no diretório do projeto
cd voice

# Instalar dependências Python
pip install -r requirements.txt

# Executar o servidor backend
cd code
python server.py
```

### Frontend (NextJS)
```bash
# Entrar no diretório do frontend
cd nextjs-voice-chat

# Instalar dependências Node.js
npm install

# Executar o servidor de desenvolvimento
npm run dev
```

## 📋 Funcionalidades

### Frontend (NextJS)
- ✅ Interface moderna e responsiva com Tailwind CSS
- ✅ WebRTC para captura de áudio do microfone
- ✅ Audio Worklets para processamento de PCM
- ✅ WebSocket para comunicação em tempo real
- ✅ Chat interface com mensagens tipadas
- ✅ Controle de velocidade de resposta
- ✅ Histórico de conversas
- ✅ Copy para clipboard

### Backend (FastAPI)
- ✅ API REST com documentação automática (Swagger)
- ✅ WebSocket para streaming de áudio
- ✅ Processamento de voz com IA
- ✅ Text-to-Speech (TTS) em tempo real com **Orpheus BR-Speech**
- ✅ Speech-to-Text (STT) com Whisper **em Português Brasileiro**
- ✅ Integração com LLMs (Ollama, LM Studio)
- ✅ CORS configurado para frontend
- ✅ **Modelo Orpheus otimizado para Português Brasileiro**

## 🎙️ Modelo Orpheus BR-Speech

Este projeto utiliza o modelo [**Orpheus BR-Speech 3B**](https://huggingface.co/freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF) da Hugging Face, especificamente otimizado para **português brasileiro**:

- **Tamanho**: 3.3B parâmetros
- **Formato**: GGUF (otimizado para inference)
- **Arquitetura**: Baseado em Llama
- **Especialização**: Text-to-Speech em português brasileiro
- **Vantagens**: 
  - ⚡ Rápida inferência com GGUF
  - 🇧🇷 Pronunciação natural em português
  - 💾 Tamanho otimizado (32-bits)
  - 🎯 Fine-tuned para BR-Speech

## 🔧 Configuração

### Variáveis de Ambiente

#### Backend
- `MAX_AUDIO_QUEUE_SIZE`: Tamanho máximo da fila de áudio (padrão: 50)
- `PYTHONPATH`: Caminho dos módulos Python
- `TTS_START_ENGINE`: Engine TTS (padrão: orpheus)
- `TTS_ORPHEUS_MODEL`: Modelo Orpheus (padrão: freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF)
- `LLM_START_PROVIDER`: Provedor LLM (padrão: ollama)
- `LLM_START_MODEL`: Modelo LLM
- `DIRECT_STREAM`: Streaming direto (padrão: true para Orpheus)
- `NO_THINK`: Desabilitar modo "thinking"
- `LANGUAGE`: Idioma para transcrição (padrão: pt para Português Brasileiro)

#### Frontend
- `NODE_ENV`: Ambiente (development/production)
- `NEXT_TELEMETRY_DISABLED`: Desabilitar telemetria do Next.js

### Arquivos de Configuração

- `docker-compose.yml`: Orquestração dos serviços
- `Dockerfile.backend`: Build do backend Python
- `nextjs-voice-chat/Dockerfile`: Build do frontend NextJS
- `nextjs-voice-chat/next.config.mjs`: Configuração do NextJS

## 📊 Monitoramento

### Health Checks
Ambos os serviços possuem health checks configurados:

```bash
# Verificar status do backend
curl http://localhost:8000/health

# Verificar status do frontend
curl http://localhost:3000/api/health
```

### Logs
```bash
# Ver logs de ambos os serviços
docker-compose logs -f

# Ver logs apenas do backend
docker-compose logs -f backend

# Ver logs apenas do frontend
docker-compose logs -f frontend
```

## 🔄 Desenvolvimento e Deploy

### Rebuild de um serviço específico
```bash
# Rebuildar apenas o backend
docker-compose up --build backend

# Rebuildar apenas o frontend
docker-compose up --build frontend
```

### Volumes Persistentes
- `./models`: Modelos de IA (backend)
- `./data`: Dados da aplicação (backend)

## 🐛 Troubleshooting

### Problemas Comuns

1. **Erro de conexão WebSocket**
   - Verificar se o backend está rodando na porta 8000
   - Verificar CORS no backend

2. **Erro de permissão de microfone**
   - Usar HTTPS em produção
   - Permitir acesso ao microfone no browser

3. **Build do frontend falha**
   - Verificar se todas as dependências estão instaladas
   - Limpar cache: `npm clean-install`

### Comandos Úteis
```bash
# Limpar containers e volumes
docker-compose down -v

# Rebuild completo sem cache
docker-compose build --no-cache

# Ver uso de recursos
docker stats

# Entrar no container do backend
docker-compose exec backend bash

# Entrar no container do frontend
docker-compose exec frontend sh
```

## 📁 Estrutura do Projeto

```
voice/
├── code/                          # Backend Python
│   ├── server.py                  # Servidor FastAPI
│   ├── audio_module.py            # Processamento de áudio
│   ├── llm_module.py              # Integração com LLMs
│   └── ...
├── nextjs-voice-chat/             # Frontend NextJS
│   ├── src/
│   │   ├── app/                   # App Router do NextJS
│   │   ├── components/            # Componentes React
│   │   └── ...
│   ├── public/                    # Arquivos estáticos
│   │   ├── pcmWorkletProcessor.js # Audio Worklet PCM
│   │   └── ttsPlaybackProcessor.js # Audio Worklet TTS
│   └── Dockerfile                 # Build do frontend
├── docker-compose.yml             # Orquestração
├── Dockerfile.backend             # Build do backend
├── requirements.txt               # Deps Python
└── README-SEPARATED.md            # Este arquivo
```

## 🎙️ Uso do Modelo Orpheus BR-Speech

### Download do Modelo
```bash
# Baixar modelo automaticamente
./download-orpheus-model.sh

# Ou manualmente via git
git lfs install
git clone https://huggingface.co/freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF models/orpheus-brspeech-3b-0.1-ft-32bits-GGUF
```

### Configuração do Modelo
O modelo será automaticamente detectado pelo sistema quando estiver no diretório `models/`. 

Configurações disponíveis:
- **Engine**: `orpheus` (padrão)
- **Modelo**: `freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF`
- **Streaming**: Direto (DIRECT_STREAM=true)
- **Formato**: GGUF 32-bits para melhor compatibilidade

### Vantagens do Modelo BR-Speech
- 🇧🇷 **Pronunciação natural** em português brasileiro
- ⚡ **Baixa latência** com formato GGUF otimizado
- 🎯 **Especializado** para Text-to-Speech
- 💾 **Tamanho eficiente** (3.3B parâmetros)
- 🔊 **Qualidade de áudio** superior para português
- 🎙️ **Transcrição** configurada para português brasileiro
- 💬 **Pipeline completo** PT-BR: Speech-to-Text → LLM → Text-to-Speech

## 🎯 Próximos Passos

- [ ] Implementar autenticação de usuários
- [ ] Adicionar persistência de conversas
- [ ] Implementar salas de chat múltiplas
- [ ] Adicionar métricas e monitoring
- [ ] Deploy em Kubernetes
- [ ] Implementar rate limiting
- [ ] Adicionar testes automatizados
- [ ] Suporte a múltiplos idiomas além do português 