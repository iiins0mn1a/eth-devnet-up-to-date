#!/bin/sh
set -e

# Geth entrypoint script
exec geth \
  --http \
  --http.api=eth,net,web3 \
  --http.addr=0.0.0.0 \
  --http.corsdomain=* \
  --ws \
  --ws.api=eth,net,web3 \
  --ws.addr=0.0.0.0 \
  --ws.origins=* \
  --authrpc.vhosts=* \
  --authrpc.addr=0.0.0.0 \
  --authrpc.jwtsecret=/execution/jwtsecret \
  --datadir=/execution \
  --allow-insecure-unlock \
  --unlock=0x123463a4b065722e99115d6c222f267d9cabb524 \
  --password=/execution/geth_password.txt \
  --nodiscover \
  --syncmode=full \
  "$@" 