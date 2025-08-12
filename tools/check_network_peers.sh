#!/bin/bash

for port in 7777 7778 7779 7780; do
    echo "Port $port:"
    curl -s "http://localhost:$port/eth/v1/node/peers" | jq '.data | length'
done