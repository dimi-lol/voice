# Multi-stage build for Voice Chat Application
FROM node:18-alpine AS frontend-builder

WORKDIR /app/frontend

# Copy package files
COPY nextjs-voice-chat/package*.json ./

# Install dependencies with increased memory and timeout
RUN npm config set fetch-retry-mintimeout 20000 && \
    npm config set fetch-retry-maxtimeout 120000 && \
    npm install --prefer-offline --no-audit --progress=false

# Copy source code
COPY nextjs-voice-chat/ ./

# Build the application
RUN npm run build

# Backend stage with CUDA support for AWS
FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04 AS python-builder

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    build-essential \
    git \
    curl \
    wget \
    ffmpeg \
    libsndfile1 \
    portaudio19-dev && \
    rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip3 install --no-cache-dir --upgrade pip && \
    pip3 install --no-cache-dir -r requirements.txt

# Copy backend code
COPY code/ ./code/

# Final runtime stage
FROM node:18-alpine AS runtime

# Install Python and system dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    python3-dev \
    build-base \
    linux-headers \
    curl \
    bash \
    supervisor \
    ffmpeg \
    portaudio-dev \
    libsndfile-dev \
    git

WORKDIR /app

# Copy built frontend
COPY --from=frontend-builder /app/frontend/.next ./.next
COPY --from=frontend-builder /app/frontend/public ./public
COPY --from=frontend-builder /app/frontend/package*.json ./
COPY --from=frontend-builder /app/frontend/next.config.* ./

# Install only production dependencies for frontend
RUN npm install --production --prefer-offline --no-audit

# Copy backend code
COPY --from=python-builder /app/code ./code

# Copy Python requirements and install
COPY requirements.txt .
RUN pip3 install --no-cache-dir -r requirements.txt

# Copy service management scripts
COPY start-services.sh ./
COPY supervisord.conf ./
RUN chmod +x start-services.sh

# Create necessary directories
RUN mkdir -p /app/models /app/data /app/logs /app/temp

# Environment variables
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PYTHONPATH=/app/code
ENV MAX_AUDIO_QUEUE_SIZE=50
ENV TTS_START_ENGINE=orpheus
ENV TTS_ORPHEUS_MODEL=freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF
ENV DIRECT_STREAM=true
ENV LANGUAGE=pt

# Expose ports
EXPOSE 3000 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:3000/api/health && curl -f http://localhost:8000/health

# Default command
CMD ["./start-services.sh"]
