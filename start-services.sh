#!/bin/bash
set -e

# Ensure we're in the right directory
cd /app

# Function to wait for a service to be ready
wait_for_service() {
    local service=$1
    local url=$2
    local max_attempts=30
    local attempt=1

    echo "Waiting for $service to be ready..."
    while ! curl -s "$url" > /dev/null; do
        if [ $attempt -eq $max_attempts ]; then
            echo "$service failed to start after $max_attempts attempts"
            exit 1
        fi
        echo "Attempt $attempt: $service not ready yet..."
        sleep 2
        ((attempt++))
    done
    echo "$service is ready!"
}

# Start the backend service
echo "Starting Python backend..."
cd /app/code
python -m uvicorn server:app --host 0.0.0.0 --port 8000 &
BACKEND_PID=$!

# Wait for backend to be ready
wait_for_service "Backend" "http://localhost:8000/health"

# Start the frontend service
echo "Starting NextJS frontend..."
cd /app/frontend
node server.js &
FRONTEND_PID=$!

# Wait for frontend to be ready
wait_for_service "Frontend" "http://localhost:3000/api/health"

echo "All services are running!"

# Function to handle shutdown
cleanup() {
    echo "Shutting down services..."
    kill $FRONTEND_PID
    kill $BACKEND_PID
    wait
    echo "All services stopped"
}

# Set up signal trapping
trap cleanup SIGTERM SIGINT

# Keep the script running
wait 