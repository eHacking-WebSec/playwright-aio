#!/bin/bash

CONTAINER_NAME="playwright-aio"

if command -v podman >/dev/null 2>&1; then
    RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
    RUNTIME=docker
else
    echo "Error: neither podman nor docker is installed."
    exit 1
fi

echo "Stopping Playwright AIO Runner (using $RUNTIME)..."

# Stop the container
if $RUNTIME ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    $RUNTIME stop $CONTAINER_NAME
    echo "Container stopped."
else
    echo "Container is not running."
fi

# Remove the container
if $RUNTIME ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    $RUNTIME rm $CONTAINER_NAME
    echo "Container removed."
else
    echo "Container does not exist."
fi

echo "Playwright AIO Runner has been stopped and removed."
