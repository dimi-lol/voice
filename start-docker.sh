#!/bin/bash

# Script para iniciar com Docker Compose
echo "🐳 Iniciando Voice Chat com Docker Compose"

# Função para limpar ao sair
cleanup() {
    echo "🛑 Parando containers..."
    docker-compose down
    exit 0
}

# Capturar Ctrl+C
trap cleanup SIGINT

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Por favor, inicie o Docker Desktop."
    exit 1
fi

# Opções de build
echo "🔧 Escolha uma opção:"
echo "1) Rebuild completo (--build)"
echo "2) Iniciar containers existentes"
echo "3) Rebuild apenas o backend"
echo "4) Rebuild apenas o frontend"
read -p "Digite sua escolha (1-4): " choice

case $choice in
    1)
        echo "🔨 Fazendo rebuild completo..."
        docker-compose up --build
        ;;
    2)
        echo "▶️  Iniciando containers existentes..."
        docker-compose up
        ;;
    3)
        echo "🔨 Rebuilding apenas o backend..."
        docker-compose up --build backend
        ;;
    4)
        echo "🔨 Rebuilding apenas o frontend..."
        docker-compose up --build frontend
        ;;
    *)
        echo "❌ Opção inválida. Usando padrão (rebuild completo)..."
        docker-compose up --build
        ;;
esac

# Aguardar
wait 