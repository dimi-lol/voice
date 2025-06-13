#!/bin/bash

# Script para build da imagem única
echo "🐳 Construindo imagem única Voice Chat"

# Função para limpar ao sair
cleanup() {
    echo "🛑 Build interrompido"
    exit 1
}

# Capturar Ctrl+C
trap cleanup SIGINT

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Por favor, inicie o Docker Desktop."
    exit 1
fi

# Opções de build
echo "🔧 Opções de build:"
echo "1) Build rápido (usar cache)"
echo "2) Build limpo (--no-cache)"
echo "3) Build e executar"
echo "4) Build com supervisord"
read -p "Digite sua escolha (1-4): " choice

BUILD_ARGS=""
RUN_AFTER=false
USE_SUPERVISOR=false

case $choice in
    1)
        echo "⚡ Build rápido com cache..."
        ;;
    2)
        echo "🧹 Build limpo sem cache..."
        BUILD_ARGS="--no-cache"
        ;;
    3)
        echo "🚀 Build e executar..."
        RUN_AFTER=true
        ;;
    4)
        echo "📋 Build com supervisord..."
        BUILD_ARGS="--build-arg USE_SUPERVISOR=true"
        USE_SUPERVISOR=true
        ;;
    *)
        echo "❌ Opção inválida. Usando build rápido..."
        ;;
esac

# Fazer build da imagem
echo "🔨 Construindo imagem voice-chat:latest..."
docker build $BUILD_ARGS -t voice-chat:latest -f Dockerfile .

if [ $? -eq 0 ]; then
    echo "✅ Build concluído com sucesso!"
    
    # Mostrar informações da imagem
    echo ""
    echo "📊 Informações da imagem:"
    docker images voice-chat:latest
    
    # Executar se solicitado
    if [ "$RUN_AFTER" = true ]; then
        echo ""
        echo "🚀 Iniciando container..."
        
        # Parar container existente se houver
        docker stop voice-chat-app 2>/dev/null
        docker rm voice-chat-app 2>/dev/null
        
        # Executar novo container
        if [ "$USE_SUPERVISOR" = true ]; then
            docker run -d \
                --name voice-chat-app \
                -p 3000:3000 \
                -p 8000:8000 \
                -e USE_SUPERVISOR=true \
                -v $(pwd)/models:/app/models \
                -v $(pwd)/data:/app/data \
                -v $(pwd)/logs:/app/logs \
                voice-chat:latest
        else
            docker run -d \
                --name voice-chat-app \
                -p 3000:3000 \
                -p 8000:8000 \
                -v $(pwd)/models:/app/models \
                -v $(pwd)/data:/app/data \
                -v $(pwd)/logs:/app/logs \
                voice-chat:latest
        fi
        
        if [ $? -eq 0 ]; then
            echo "✅ Container iniciado com sucesso!"
            echo ""
            echo "🌐 URLs disponíveis:"
            echo "   Frontend: http://localhost:3000"
            echo "   Backend: http://localhost:8000"
            echo "   API Docs: http://localhost:8000/docs"
            echo ""
            echo "📋 Comandos úteis:"
            echo "   docker logs -f voice-chat-app    # Ver logs"
            echo "   docker exec -it voice-chat-app bash  # Entrar no container"
            echo "   docker stop voice-chat-app       # Parar"
            echo "   docker start voice-chat-app      # Iniciar novamente"
        else
            echo "❌ Erro ao iniciar container"
        fi
    fi
    
else
    echo "❌ Erro no build da imagem"
    exit 1
fi 