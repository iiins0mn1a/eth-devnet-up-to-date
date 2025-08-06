#!/bin/bash
set -e

# Validator 1 entrypoint script
exec /validator \
  --beacon-rpc-provider=beacon-chain-1:4000 \
  --datadir=/consensus/validatordata1 \
  --accept-terms-of-use \
  --interop-num-validators=32 \
  --interop-start-index=0 \
  --chain-config-file=/config/config-1.yml \
  --force-clear-db \
  "$@" 