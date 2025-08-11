#!/bin/bash
set -e

# Validator 3 entrypoint script
exec /validator \
  --beacon-rpc-provider=beacon-chain-3:4000 \
  --datadir=/consensus/validatordata3 \
  --accept-terms-of-use \
  --interop-num-validators=8 \
  --interop-start-index=48 \
  --chain-config-file=/config/config-3.yml \
  --monitoring-host=0.0.0.0 \
  --monitoring-port=8080 \
  --force-clear-db \
  "$@" 