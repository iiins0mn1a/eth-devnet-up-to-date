#!/bin/bash
set -euo pipefail

# Generic Validator entrypoint (Prysm)
# Parametrized via environment variables to avoid per-node scripts.

BEACON_RPC_PROVIDER="${BEACON_RPC_PROVIDER:-}"
DATA_DIR="${DATA_DIR:-}"
CHAIN_CONFIG_FILE="${CHAIN_CONFIG_FILE:-}"
INTEROP_NUM_VALIDATORS="${INTEROP_NUM_VALIDATORS:-}"
INTEROP_START_INDEX="${INTEROP_START_INDEX:-}"
MONITORING_HOST="${MONITORING_HOST:-0.0.0.0}"
MONITORING_PORT="${MONITORING_PORT:-8080}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${2}"; }
err() { log ERROR "$1"; }
require() { local n="$1"; local v="$2"; if [ -z "$v" ]; then err "缺少必要环境变量: $n"; exit 1; fi }

main() {
  require BEACON_RPC_PROVIDER "$BEACON_RPC_PROVIDER"
  require DATA_DIR "$DATA_DIR"
  require CHAIN_CONFIG_FILE "$CHAIN_CONFIG_FILE"
  require INTEROP_NUM_VALIDATORS "$INTEROP_NUM_VALIDATORS"
  require INTEROP_START_INDEX "$INTEROP_START_INDEX"

  exec /validator \
    --beacon-rpc-provider="$BEACON_RPC_PROVIDER" \
    --datadir="$DATA_DIR" \
    --accept-terms-of-use \
    --interop-num-validators="$INTEROP_NUM_VALIDATORS" \
    --interop-start-index="$INTEROP_START_INDEX" \
    --chain-config-file="$CHAIN_CONFIG_FILE" \
    --monitoring-host="$MONITORING_HOST" \
    --monitoring-port="$MONITORING_PORT" \
    --force-clear-db
}

main "$@"


