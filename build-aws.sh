#!/bin/bash

# Script para build na AWS
echo "🚀 Construindo imagem Voice Chat para AWS"

# Função para limpar ao sair
cleanup() {
    echo "🛑 Build interrompido"
    exit 1
}

# Capturar Ctrl+C
trap cleanup SIGINT

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker não está rodando. Por favor, inicie o Docker."
    exit 1
fi

# Opções de build
echo "🔧 Opções de build para AWS:"
echo "1) Build com Dockerfile.aws (CPU otimizado)"
echo "2) Build com Dockerfile original (CUDA)"
echo "3) Build minimal (economia de espaço) - RECOMENDADO"
echo "4) Build limpo sem cache"
echo "5) Build e executar localmente"
read -p "Digite sua escolha (1-5): " choice

BUILD_ARGS=""
DOCKERFILE="Dockerfile.aws"
RUN_AFTER=false

case $choice in
    1)
        echo "⚡ Build AWS otimizado..."
        DOCKERFILE="Dockerfile.aws"
        ;;
    2)
        echo "🎮 Build com CUDA..."
        DOCKERFILE="Dockerfile"
        ;;
    3)
        echo "💾 Build minimal (economia de espaço)..."
        DOCKERFILE="Dockerfile.minimal"
        ;;
    4)
        echo "🧹 Build limpo sem cache..."
        BUILD_ARGS="--no-cache"
        DOCKERFILE="Dockerfile.minimal"
        ;;
    5)
        echo "🚀 Build e executar..."
        RUN_AFTER=true
        DOCKERFILE="Dockerfile.minimal"
        ;;
    *)
        echo "❌ Opção inválida. Usando minimal..."
        DOCKERFILE="Dockerfile.minimal"
        ;;
esac

# Fazer build da imagem
echo "🔨 Construindo imagem voice-chat-aws:latest com $DOCKERFILE..."
docker build $BUILD_ARGS -t voice-chat-aws:latest -f $DOCKERFILE .

if [ $? -eq 0 ]; then
    echo "✅ Build concluído com sucesso!"
    
    # Mostrar informações da imagem
    echo ""
    echo "📊 Informações da imagem:"
    docker images voice-chat-aws:latest
    
    # Executar se solicitado
    if [ "$RUN_AFTER" = true ]; then
        echo ""
        echo "🚀 Iniciando container..."
        
        # Parar container existente se houver
        docker stop voice-chat-aws-app 2>/dev/null
        docker rm voice-chat-aws-app 2>/dev/null
        
        # Executar novo container
        docker run -d \
            --name voice-chat-aws-app \
            -p 3000:3000 \
            -p 8000:8000 \
            -v $(pwd)/models:/app/models \
            -v $(pwd)/data:/app/data \
            -v $(pwd)/logs:/app/logs \
            voice-chat-aws:latest
        
        if [ $? -eq 0 ]; then
            echo "✅ Container iniciado com sucesso!"
            echo ""
            echo "🌐 URLs disponíveis:"
            echo "   Frontend: http://localhost:3000"
            echo "   Backend: http://localhost:8000"
            echo "   API Docs: http://localhost:8000/docs"
            echo ""
            echo "📋 Comandos úteis:"
            echo "   docker logs -f voice-chat-aws-app    # Ver logs"
            echo "   docker exec -it voice-chat-aws-app bash  # Entrar no container"
            echo "   docker stop voice-chat-aws-app       # Parar"
            echo "   docker start voice-chat-aws-app      # Iniciar novamente"
        else
            echo "❌ Erro ao iniciar container"
        fi
    fi
    
    # Instruções para AWS
    echo ""
    echo "🌩️  Para fazer deploy na AWS:"
    echo "   1. Tag a imagem: docker tag voice-chat-aws:latest YOUR_ECR_REPO:latest"
    echo "   2. Push para ECR: docker push YOUR_ECR_REPO:latest"
    echo "   3. Deploy no ECS/EKS usando a imagem"
    
else
    echo "❌ Erro no build da imagem"
    exit 1
fi 