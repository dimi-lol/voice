# Multi-stage build for combined NextJS frontend + Python backend
FROM node:18-slim AS frontend-builder

# Build the NextJS frontend
WORKDIR /app/frontend

# Install dependencies
COPY nextjs-voice-chat/package*.json ./
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production
RUN npm ci

# Copy and build frontend
COPY nextjs-voice-chat/ ./
RUN npm run build

# ---

FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04 AS python-builder

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Python and build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    python3.10-dev \
    python3.10-venv \
    build-essential \
    git \
    libsndfile1 \
    libportaudio2 \
    ffmpeg \
    portaudio19-dev \
    python3-setuptools \
    python3.10-distutils \
    ninja-build \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Make python3.10 the default python/pip
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Set working directory
WORKDIR /app

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip

# Install PyTorch with CUDA 12.1 support
RUN pip install --no-cache-dir \
    torch==2.1.2+cu121 \
    torchaudio==2.1.2+cu121 \
    torchvision==0.16.2+cu121 \
    --index-url https://download.pytorch.org/whl/cu121

# Install DeepSpeed
ENV DS_BUILD_TRANSFORMER=1
ENV DS_BUILD_CPU_ADAM=0
ENV DS_BUILD_FUSED_ADAM=0
ENV DS_BUILD_UTILS=0
ENV DS_BUILD_OPS=0

RUN pip install --no-cache-dir deepspeed \
    || (echo "DeepSpeed install failed. Check build logs above." && exit 1)

# Copy requirements file first to leverage Docker cache
COPY requirements.txt .

# Install remaining Python dependencies from requirements.txt
RUN pip install --no-cache-dir --prefer-binary -r requirements.txt \
    || (echo "pip install -r requirements.txt FAILED." && exit 1)

# Pin ctranslate2 to a compatible version
RUN pip install --no-cache-dir "ctranslate2<4.5.0"

# ---

FROM nvidia/cuda:12.1.1-cudnn8-devel-ubuntu22.04

# Avoid prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install Node.js 18.x, Python, and runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    gnupg \
    && mkdir -p /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_18.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y --no-install-recommends \
    nodejs \
    python3.10 \
    python3-pip \
    python3.10-dev \
    libsndfile1 \
    ffmpeg \
    libportaudio2 \
    python3-setuptools \
    python3.10-distutils \
    ninja-build \
    build-essential \
    g++ \
    gosu \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Make python3.10 the default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.10 1 && \
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Create application directory
WORKDIR /app

# Copy Python packages from builder stage
RUN mkdir -p /usr/local/lib/python3.10/dist-packages
COPY --from=python-builder /usr/local/lib/python3.10/dist-packages /usr/local/lib/python3.10/dist-packages

# Copy the backend code
COPY code/ ./code/

# Copy the built frontend from frontend-builder stage
COPY --from=frontend-builder /app/frontend/.next/standalone ./frontend/
COPY --from=frontend-builder /app/frontend/.next/static ./frontend/.next/static
COPY --from=frontend-builder /app/frontend/public ./frontend/public

# Pre-download models
# Silero VAD Pre-download
RUN echo "Preloading Silero VAD model..." && \
    python3 <<EOF
import torch
import os
try:
    cache_dir = os.path.expanduser("~/.cache/torch")
    os.environ['TORCH_HOME'] = cache_dir
    print(f"Using TORCH_HOME: {cache_dir}")
    torch.hub.load(
        repo_or_dir='snakers4/silero-vad',
        model='silero_vad',
        force_reload=False,
        onnx=False,
        trust_repo=True
    )
    print("Silero VAD download successful.")
except Exception as e:
    print(f"Error downloading Silero VAD: {e}")
    exit(1)
EOF

# faster-whisper Pre-download
ARG WHISPER_MODEL=base
ENV WHISPER_MODEL=${WHISPER_MODEL}
RUN echo "Preloading faster_whisper model: ${WHISPER_MODEL}" && \
    python3 -c "import os; print(f\"Downloading STT model: {os.getenv('WHISPER_MODEL')}\"); import faster_whisper; model = faster_whisper.WhisperModel(os.getenv('WHISPER_MODEL'), device='cpu'); print('Model download successful.')" \
    || (echo "Faster Whisper download failed" && exit 1)

# SentenceFinishedClassification Pre-download
RUN echo "Preloading SentenceFinishedClassification model..." && \
    python3 -c "from transformers import DistilBertTokenizerFast, DistilBertForSequenceClassification; \
                print('Downloading tokenizer...'); \
                tokenizer = DistilBertTokenizerFast.from_pretrained('KoljaB/SentenceFinishedClassification'); \
                print('Downloading classification model...'); \
                model = DistilBertForSequenceClassification.from_pretrained('KoljaB/SentenceFinishedClassification'); \
                print('Model downloads successful.')" \
    || (echo "Sentence Classifier download failed" && exit 1)

# Create a non-root user and group
RUN groupadd --gid 1001 appgroup && \
    useradd --uid 1001 --gid 1001 --create-home appuser

# Ensure directories are owned by appuser
RUN mkdir -p /home/appuser/.cache && \
    chown -R appuser:appgroup /app && \
    chown -R appuser:appgroup /home/appuser && \
    if [ -d /root/.cache ]; then chown -R appuser:appgroup /root/.cache; fi

# Copy service management scripts
COPY start-services.sh /start-services.sh
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN chmod +x /start-services.sh

# Set environment variables
ENV HOME=/home/appuser
ENV CUDA_HOME=/usr/local/cuda
ENV PATH="${CUDA_HOME}/bin:${PATH}"
ENV LD_LIBRARY_PATH="${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}"
ENV PYTHONUNBUFFERED=1
ENV MAX_AUDIO_QUEUE_SIZE=50
ENV LOG_LEVEL=INFO
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility
ENV RUNNING_IN_DOCKER=true
ENV DS_BUILD_OPS=1
ENV DS_BUILD_CPU_ADAM=0
ENV DS_BUILD_FUSED_ADAM=0
ENV DS_BUILD_UTILS=0
ENV DS_BUILD_TRANSFORMER=1
ENV HF_HOME=${HOME}/.cache/huggingface
ENV TORCH_HOME=${HOME}/.cache/torch
ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

# Portuguese/Brazilian configuration
ENV LANGUAGE=pt
ENV TTS_MODEL_NAME=freds0/orpheus-brspeech-3b-0.1-ft-32bits-GGUF
ENV TTS_FILE_NAME=orpheus-brspeech-3b-0.1-ft-q8_0.gguf

# Expose ports for both frontend and backend
EXPOSE 3000 8000

# Use start-services.sh as the default command
CMD ["/start-services.sh"]
