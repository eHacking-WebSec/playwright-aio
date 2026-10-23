#!/bin/bash

CONTAINER_NAME="playwright-aio"
IMAGE_NAME="playwright-aio:local"

if command -v podman >/dev/null 2>&1; then
    RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
    RUNTIME=docker
else
    echo "Error: neither podman nor docker is installed."
    exit 1
fi

echo "Building and starting Playwright AIO Runner (using $RUNTIME)..."

# Stop and remove existing container if running
if $RUNTIME ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Stopping and removing existing container..."
    $RUNTIME stop $CONTAINER_NAME 2>/dev/null
    $RUNTIME rm $CONTAINER_NAME 2>/dev/null
fi

# Build the image
echo "Building image..."
$RUNTIME build -t $IMAGE_NAME .

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

# Run the container
echo "Starting container..."
$RUNTIME run -d \
    --name $CONTAINER_NAME \
    -p 8080:8080 \
    -p 6080:6080 \
    --shm-size=2gb \
    $IMAGE_NAME

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Playwright AIO Runner is now running!"
    echo "=========================================="
    echo ""
    echo "Web Interface: http://localhost:8080"
    echo ""
    echo "To stop the container, run: ./stop.sh"
    echo ""
else
    echo "Failed to start container!"
    exit 1
fi
