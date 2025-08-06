#!/bin/bash
set -e

# Validator 4 entrypoint script
exec /validator \
  --beacon-rpc-provider=beacon-chain-4:4000 \
  --datadir=/consensus/validatordata4 \
  --accept-terms-of-use \
  --interop-num-validators=8 \
  --interop-start-index=56 \
  --chain-config-file=/config/config-4.yml \
  --force-clear-db \
  "$@" 