#!/bin/bash
set -e

# Validator 2 entrypoint script
exec /validator \
  --beacon-rpc-provider=beacon-chain-2:4000 \
  --datadir=/consensus/validatordata2 \
  --accept-terms-of-use \
  --interop-num-validators=16 \
  --interop-start-index=32 \
  --chain-config-file=/config/config-2.yml \
  --monitoring-host=0.0.0.0 \
  --monitoring-port=8080 \
  --force-clear-db \
  "$@" 