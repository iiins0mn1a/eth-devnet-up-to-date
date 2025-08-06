#!/bin/bash

./scripts/start-services.sh

echo "Starting Ethereum PoS Devnet..."
sudo docker compose up -d

echo "Services started successfully!"
echo "Check logs with: docker-compose logs -f" 