#!/bin/bash

# Script de setup inicial para Voice Chat
echo "🚀 Setup inicial do Voice Chat - Frontend + Backend separados"
echo ""

# Verificar dependências do sistema
echo "🔍 Verificando dependências do sistema..."

# Verificar Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 não encontrado. Por favor, instale Python 3.11+"
    exit 1
fi
echo "✅ Python $(python3 --version) encontrado"

# Verificar Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js não encontrado. Por favor, instale Node.js 18+"
    exit 1
fi
echo "✅ Node.js $(node --version) encontrado"

# Verificar npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm não encontrado. Por favor, instale npm"
    exit 1
fi
echo "✅ npm $(npm --version) encontrado"

# Verificar Docker (opcional)
if command -v docker &> /dev/null; then
    echo "✅ Docker $(docker --version | cut -d' ' -f3 | cut -d',' -f1) encontrado"
    DOCKER_AVAILABLE=true
else
    echo "⚠️  Docker não encontrado (opcional para desenvolvimento local)"
    DOCKER_AVAILABLE=false
fi

echo ""

# Criar ambiente virtual Python se não existir
if [ ! -d "venv" ]; then
    echo "🐍 Criando ambiente virtual Python..."
    python3 -m venv venv
fi

# Ativar ambiente virtual
echo "🔧 Ativando ambiente virtual..."
source venv/bin/activate

# Instalar dependências Python
echo "📦 Instalando dependências Python..."
pip install --upgrade pip
pip install -r requirements.txt

# Instalar dependências Node.js
echo "📦 Instalando dependências Node.js..."
cd nextjs-voice-chat
npm install
cd ..

# Criar diretórios necessários
echo "📁 Criando diretórios necessários..."
mkdir -p models data logs

# Dar permissões aos scripts
echo "🔑 Configurando permissões..."
chmod +x start-dev.sh
chmod +x start-docker.sh
chmod +x download-orpheus-model.sh

# Perguntar se deve baixar o modelo Orpheus
echo ""
read -p "🎙️ Deseja baixar o modelo Orpheus BR-Speech agora? (y/n): " download_model

if [[ $download_model =~ ^[Yy]$ ]]; then
    echo "📥 Baixando modelo Orpheus BR-Speech..."
    ./download-orpheus-model.sh
else
    echo "⏭️ Modelo não baixado. Execute './download-orpheus-model.sh' quando necessário."
fi

echo ""
echo "✅ Setup concluído com sucesso!"
echo ""
echo "📋 Próximos passos:"
echo ""
echo "🔧 Para desenvolvimento local:"
echo "   ./start-dev.sh"
echo ""

if [ "$DOCKER_AVAILABLE" = true ]; then
echo "🐳 Para execução com Docker:"
echo "   ./start-docker.sh"
echo ""
fi

echo "📚 Documentação:"
echo "   - README-SEPARATED.md - Guia completo"
echo "   - config.env.example - Configurações"
echo ""
echo "🌐 URLs após iniciar:"
echo "   - Frontend: http://localhost:3000"
echo "   - Backend API: http://localhost:8000"
echo "   - API Docs: http://localhost:8000/docs"
echo ""
echo "💡 Dica: Use o VS Code com as extensões Python e TypeScript para melhor experiência!" 