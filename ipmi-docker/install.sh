#!/bin/bash
set -e
echo "Building IPMI Docker container..."
docker-compose build

echo "Starting container..."
docker-compose up -d --force-recreate

echo "Installation complete!"
echo "Try running: docker exec ipmi-tools ipmi-manager list-hosts"
