#!/bin/bash
set -e

# Beacon Chain 3 entrypoint script

# 信号等待函数
wait_for_signal() {
    local signal_file="/share/signals/$1"
    echo "[$(date)] 等待信号: $1"
    while [ ! -f "$signal_file" ]; do
        sleep 0.5
    done
    echo "[$(date)] 收到信号: $1"
}

# 读取 bootstrap 节点信息
get_bootstrap_node() {
    if [ -f "/share/bootstrap_enr.txt" ]; then
        cat /share/bootstrap_enr.txt
    else
        echo ""
    fi
}

# 如果是集成模式，等待相应信号
if [ "$NS3_INTEGRATION" = "true" ]; then
    echo "[$(date)] NS-3 集成模式启动 beacon-chain-3"
    
    # 等待 NS-3 网络配置完成
    wait_for_signal "ns3_network_ready.lock"
    
    # 等待 bootstrap 信息就绪
    wait_for_signal "bootstrap_ready.lock"
    
    # 等待网络启动许可
    wait_for_signal "network_ready.lock"
    
    echo "[$(date)] 信号检查完成，启动 beacon-chain-3..."
    
    # 获取 bootstrap 节点信息
    BOOTSTRAP_NODE=$(get_bootstrap_node)
    echo "[$(date)] Bootstrap 节点: $BOOTSTRAP_NODE"
else
    echo "[$(date)] 正常模式启动 beacon-chain-3"
    # 正常模式下直接读取 bootstrap 信息
    BOOTSTRAP_NODE=$(get_bootstrap_node)
fi

# 启动 beacon-chain（在集成模式下添加 p2p-host-port 参数）
if [ "$NS3_INTEGRATION" = "true" ]; then
    # NS-3 集成模式：使用指定的 IP 地址
    exec /beacon-chain \
      --datadir=/consensus/beacondata3 \
      --p2p-host-ip=10.0.0.3 \
      --p2p-local-ip=10.0.0.3 \
      --p2p-tcp-port=13000 \
      --p2p-udp-port=12000 \
      --p2p-allowlist=10.0.0.0/16 \
      --min-sync-peers=0 \
      --genesis-state=/consensus/genesis.ssz \
      --bootstrap-node="$BOOTSTRAP_NODE" \
      --interop-eth1data-votes \
      --chain-config-file=/config/config-3.yml \
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
      --monitoring-host=0.0.0.0 \
      --monitoring-port=8080 \
      --force-clear-db \
      --p2p-static-id=true \
      --p2p-max-peers=70 \
      "$@"
else
    # 正常模式：使用原有参数
    exec /beacon-chain \
      --datadir=/consensus/beacondata3 \
      --min-sync-peers=0 \
      --genesis-state=/consensus/genesis.ssz \
      --bootstrap-node="$BOOTSTRAP_NODE" \
      --interop-eth1data-votes \
      --chain-config-file=/config/config-3.yml \
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
      --monitoring-host=0.0.0.0 \
      --monitoring-port=8080 \
      --force-clear-db \
      --p2p-static-id=true \
      --p2p-max-peers=70 \
      "$@"
fi