#!/bin/bash

# Script para baixar o modelo Orpheus BR-Speech da Hugging Face
echo "🎙️ Baixando modelo Orpheus BR-Speech da Hugging Face"
echo "📍 Modelo: freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF"
echo ""

# Verificar se git-lfs está instalado
if ! command -v git-lfs &> /dev/null; then
    echo "❌ git-lfs não encontrado. Instalando..."
    
    # Detectar sistema operacional
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v brew &> /dev/null; then
            brew install git-lfs
        else
            echo "❌ Homebrew não encontrado. Por favor, instale git-lfs manualmente:"
            echo "   https://git-lfs.github.io/"
            exit 1
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install git-lfs
        elif command -v yum &> /dev/null; then
            sudo yum install git-lfs
        else
            echo "❌ Gerenciador de pacotes não suportado. Por favor, instale git-lfs manualmente:"
            echo "   https://git-lfs.github.io/"
            exit 1
        fi
    else
        echo "❌ Sistema operacional não suportado. Por favor, instale git-lfs manualmente:"
        echo "   https://git-lfs.github.io/"
        exit 1
    fi
fi

# Inicializar git-lfs
git lfs install

# Criar diretório para modelos
mkdir -p models
cd models

# Verificar se o modelo já existe
if [ -d "orpheus-brspeech-3b-0.1-ft-32bits-GGUF" ]; then
    echo "📁 Modelo já existe. Atualizando..."
    cd orpheus-brspeech-3b-0.1-ft-32bits-GGUF
    git pull
    cd ..
else
    echo "📥 Clonando modelo da Hugging Face..."
    git clone https://huggingface.co/freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF
fi

# Verificar se o download foi bem-sucedido
if [ -d "orpheus-brspeech-3b-0.1-ft-32bits-GGUF" ]; then
    echo ""
    echo "✅ Modelo Orpheus BR-Speech baixado com sucesso!"
    echo "📁 Localização: $(pwd)/orpheus-brspeech-3b-0.1-ft-32bits-GGUF"
    echo ""
    echo "📊 Informações do modelo:"
    echo "   - Tamanho: 3.3B parâmetros"
    echo "   - Formato: GGUF (32-bits)"
    echo "   - Especialização: TTS Português Brasileiro"
    echo "   - Origem: https://huggingface.co/freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF"
    echo ""
    echo "🚀 O modelo está pronto para uso!"
    echo "   Execute ./start-dev.sh ou ./start-docker.sh para iniciar"
else
    echo "❌ Erro ao baixar o modelo. Verifique sua conexão com a internet."
    exit 1
fi 