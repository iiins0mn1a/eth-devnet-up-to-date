#!/bin/bash
set -euo pipefail

# Generic Beacon Chain entrypoint (Prysm)
# Parametrized via environment variables to avoid per-node scripts.

# Required/optional env
NODE_ID="${NODE_ID:-}"
NODE_IP="${NODE_IP:-}"
API_PORT="${API_PORT:-7777}"
SIGNAL_DIR="${SIGNAL_DIR:-/share/signals}"
BOOTSTRAP_FILE="${BOOTSTRAP_FILE:-/share/bootstrap_enr.txt}"
DATA_DIR="${DATA_DIR:-}"
CONFIG_FILE="${CONFIG_FILE:-}"
GENESIS_FILE="${GENESIS_FILE:-/consensus/genesis.ssz}"
JWT_SECRET="${JWT_SECRET:-/execution/jwtsecret}"
EXECUTION_ENDPOINT="${EXECUTION_ENDPOINT:-http://geth:8551}"
CHAIN_ID="${CHAIN_ID:-32382}"
NS3_INTEGRATION="${NS3_INTEGRATION:-false}"
MONITORING_HOST="${MONITORING_HOST:-0.0.0.0}"
MONITORING_PORT="${MONITORING_PORT:-8080}"
LOG_LEVEL="${LOG_LEVEL:-info}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$1] ${2}"; }
info() { log INFO "$1"; }
warn() { log WARN "$1"; }
err() { log ERROR "$1"; }

require() {
  local name="$1"; local value="$2";
  if [ -z "$value" ]; then err "缺少必要环境变量: $name"; exit 1; fi
}

wait_for_signal() {
  local sig="$1"; local path="$SIGNAL_DIR/$sig"; local timeout=300; local waited=0
  info "等待信号: $sig"
  while [ ! -f "$path" ] && [ $waited -lt $timeout ]; do sleep 0.5; waited=$((waited+1)); done
  if [ -f "$path" ]; then info "收到信号: $sig"; else err "等待信号超时: $sig"; exit 1; fi
}

get_bootstrap_node() {
  if [ -f "$BOOTSTRAP_FILE" ]; then cat "$BOOTSTRAP_FILE"; else echo ""; fi
}

main() {
  require NODE_ID "$NODE_ID"
  require DATA_DIR "$DATA_DIR"
  require CONFIG_FILE "$CONFIG_FILE"

  if [ "$NS3_INTEGRATION" = "true" ]; then
    require NODE_IP "$NODE_IP"
    wait_for_signal "ns3_network_ready.lock"
    if [ "$NODE_ID" = "1" ]; then
      wait_for_signal "beacon1_ready.lock"
    else
      wait_for_signal "bootstrap_ready.lock"
      wait_for_signal "network_ready.lock"
    fi
  fi

  local bootstrap_node=""
  if [ "$NODE_ID" != "1" ]; then
    bootstrap_node="$(get_bootstrap_node)"
  fi

  info "启动 beacon-chain 节点: $NODE_ID (NS3=$NS3_INTEGRATION)"

  if [ "$NS3_INTEGRATION" = "true" ]; then
    exec /beacon-chain \
      --datadir="$DATA_DIR" \
      --p2p-host-ip="$NODE_IP" \
      --p2p-local-ip="$NODE_IP" \
      --p2p-tcp-port=13000 \
      --p2p-udp-port=12000 \
      --p2p-allowlist=10.0.0.0/16 \
      --min-sync-peers=0 \
      --genesis-state="$GENESIS_FILE" \
      --bootstrap-node="$bootstrap_node" \
      --interop-eth1data-votes \
      --chain-config-file="$CONFIG_FILE" \
      --contract-deployment-block=0 \
      --chain-id="$CHAIN_ID" \
      --rpc-host=0.0.0.0 \
      --grpc-gateway-host=0.0.0.0 \
      --grpc-gateway-port="$API_PORT" \
      --execution-endpoint="$EXECUTION_ENDPOINT" \
      --accept-terms-of-use \
      --jwt-secret="$JWT_SECRET" \
      --suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524 \
      --minimum-peers-per-subnet=0 \
      --enable-debug-rpc-endpoints \
      --monitoring-host="$MONITORING_HOST" \
      --monitoring-port="$MONITORING_PORT" \
      --force-clear-db \
      --p2p-static-id=true \
      --p2p-max-peers=70 \
      --verbosity="$LOG_LEVEL"
  else
    exec /beacon-chain \
      --datadir="$DATA_DIR" \
      --min-sync-peers=0 \
      --genesis-state="$GENESIS_FILE" \
      --bootstrap-node="$bootstrap_node" \
      --interop-eth1data-votes \
      --chain-config-file="$CONFIG_FILE" \
      --contract-deployment-block=0 \
      --chain-id="$CHAIN_ID" \
      --rpc-host=0.0.0.0 \
      --grpc-gateway-host=0.0.0.0 \
      --grpc-gateway-port="$API_PORT" \
      --execution-endpoint="$EXECUTION_ENDPOINT" \
      --accept-terms-of-use \
      --jwt-secret="$JWT_SECRET" \
      --suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524 \
      --minimum-peers-per-subnet=0 \
      --enable-debug-rpc-endpoints \
      --monitoring-host="$MONITORING_HOST" \
      --monitoring-port="$MONITORING_PORT" \
      --force-clear-db \
      --p2p-static-id=true \
      --p2p-max-peers=70 \
      --verbosity="$LOG_LEVEL"
  fi
}

main "$@"


