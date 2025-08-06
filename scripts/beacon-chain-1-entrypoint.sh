#!/bin/bash
set -e

# Beacon Chain 1 entrypoint script
exec /beacon-chain \
  --datadir=/consensus/beacondata1 \
  --min-sync-peers=0 \
  --genesis-state=/consensus/genesis.ssz \
  --bootstrap-node= \
  --interop-eth1data-votes \
  --chain-config-file=/config/config-1.yml \
  --contract-deployment-block=0 \
  --chain-id=${CHAIN_ID:-32382} \
  --rpc-host=0.0.0.0 \
  --grpc-gateway-host=0.0.0.0 \
  --grpc-gateway-port=7777 \
  --execution-endpoint=http://geth:8551 \
  --accept-terms-of-use \
  --jwt-secret=/execution/jwtsecret \
  --suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524 \
  --minimum-peers-per-subnet=0 \
  --enable-debug-rpc-endpoints \
  --force-clear-db \
  --p2p-static-id=true \
  --p2p-max-peers=70 \
  "$@" 