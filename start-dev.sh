#!/bin/bash

# Script para iniciar o ambiente de desenvolvimento
echo "🚀 Iniciando ambiente de desenvolvimento Voice Chat"

# Função para limpar processos ao sair
cleanup() {
    echo "🛑 Parando serviços..."
    kill $(jobs -p) 2>/dev/null
    exit 0
}

# Capturar Ctrl+C
trap cleanup SIGINT

# Verificar se as dependências estão instaladas
echo "🔍 Verificando dependências..."

# Backend Python
echo "📦 Verificando dependências Python..."
if ! pip list | grep -q "fastapi"; then
    echo "⚠️  Instalando dependências Python..."
    pip install -r requirements.txt
fi

# Frontend NextJS
echo "📦 Verificando dependências Node.js..."
cd nextjs-voice-chat
if [ ! -d "node_modules" ]; then
    echo "⚠️  Instalando dependências Node.js..."
    npm install
fi

# Iniciar backend em background
echo "🐍 Iniciando backend Python (porta 8000)..."
cd ../code
python server.py &
BACKEND_PID=$!

# Aguardar o backend inicializar
echo "⏳ Aguardando backend inicializar..."
sleep 5

# Iniciar frontend
echo "⚛️  Iniciando frontend NextJS (porta 3000)..."
cd ../nextjs-voice-chat
npm run dev &
FRONTEND_PID=$!

# Mostrar informações
echo ""
echo "✅ Serviços iniciados com sucesso!"
echo "🌐 Frontend: http://localhost:3000"
echo "🔧 Backend API: http://localhost:8000"
echo "📚 Documentação API: http://localhost:8000/docs"
echo ""
echo "💡 Para parar os serviços, pressione Ctrl+C"
echo ""

# Aguardar os processos
wait 