#!/bin/bash
# =============================================================================
# Beacon Chain 1 启动脚本
# 
# 功能：
# - 作为bootstrap节点启动beacon-chain
# - 支持NS-3网络集成模式
# - 等待网络就绪信号
# 
# 网络配置：
# - NS-3 IP: 10.0.0.1
# - P2P端口: 13000 (TCP/UDP)
# - API端口: 7777
# 
# 作者：AI Assistant
# 版本：2.0
# =============================================================================

set -euo pipefail  # 严格错误处理

# =============================================================================
# 配置常量
# =============================================================================
readonly SIGNAL_DIR="/share/signals"
readonly BOOTSTRAP_FILE="/share/bootstrap_enr.txt"
readonly DATA_DIR="/consensus/beacondata1"
readonly CONFIG_FILE="/config/config-1.yml"
readonly GENESIS_FILE="/consensus/genesis.ssz"
readonly JWT_SECRET="/execution/jwtsecret"
readonly EXECUTION_ENDPOINT="http://geth:8551"

# =============================================================================
# 日志函数
# =============================================================================

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

log_debug() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $1"
}

# =============================================================================
# 工具函数
# =============================================================================

# 等待信号文件
wait_for_signal() {
    local signal_file="$SIGNAL_DIR/$1"
    log_info "等待信号: $1"
    
    local timeout=300  # 5分钟超时
    local elapsed=0
    
    while [ ! -f "$signal_file" ] && [ $elapsed -lt $timeout ]; do
        sleep 0.5
        elapsed=$((elapsed + 1))
    done
    
    if [ -f "$signal_file" ]; then
        log_info "收到信号: $1"
        return 0
    else
        log_error "等待信号超时: $1"
        return 1
    fi
}

# 检查必要文件
check_required_files() {
    local missing_files=()
    
    # 检查配置文件
    if [ ! -f "$CONFIG_FILE" ]; then
        missing_files+=("$CONFIG_FILE")
    fi
    
    # 检查创世文件
    if [ ! -f "$GENESIS_FILE" ]; then
        missing_files+=("$GENESIS_FILE")
    fi
    
    # 检查JWT密钥
    if [ ! -f "$JWT_SECRET" ]; then
        missing_files+=("$JWT_SECRET")
    fi
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "缺少必要文件:"
        for file in "${missing_files[@]}"; do
            log_error "  - $file"
        done
        return 1
    fi
    
    log_debug "所有必要文件检查通过"
    return 0
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    log_info "Beacon Chain 1 启动脚本开始执行"
    
    # 检查必要文件
    if ! check_required_files; then
        log_error "文件检查失败，退出"
        exit 1
    fi
    
    # 检查运行模式
    if [ "${NS3_INTEGRATION:-false}" = "true" ]; then
        log_info "NS-3 集成模式启动"
        
        # 等待 NS-3 网络配置完成
        if ! wait_for_signal "ns3_network_ready.lock"; then
            log_error "NS-3网络就绪信号超时"
            exit 1
        fi
        
        # 等待启动许可（作为第一个节点）
        if ! wait_for_signal "beacon1_ready.lock"; then
            log_error "beacon1启动信号超时"
            exit 1
        fi
        
        log_info "信号检查完成，启动 beacon-chain-1..."
        
        # NS-3 集成模式：使用指定的 IP 地址
        exec /beacon-chain \
            --datadir="$DATA_DIR" \
            --p2p-host-ip=10.0.0.1 \
            --p2p-local-ip=10.0.0.1 \
            --p2p-tcp-port=13000 \
            --p2p-udp-port=12000 \
            --p2p-allowlist=10.0.0.0/16 \
            --min-sync-peers=0 \
            --genesis-state="$GENESIS_FILE" \
            --bootstrap-node= \
            --interop-eth1data-votes \
            --chain-config-file="$CONFIG_FILE" \
            --contract-deployment-block=0 \
            --chain-id="${CHAIN_ID:-32382}" \
            --rpc-host=0.0.0.0 \
            --grpc-gateway-host=0.0.0.0 \
            --grpc-gateway-port=7777 \
            --execution-endpoint="$EXECUTION_ENDPOINT" \
            --accept-terms-of-use \
            --jwt-secret="$JWT_SECRET" \
            --suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524 \
            --minimum-peers-per-subnet=0 \
            --enable-debug-rpc-endpoints \
            --force-clear-db \
            --p2p-static-id=true \
            --p2p-max-peers=70 \
            --verbosity=debug \
            "$@"
    else
        log_info "正常模式启动 beacon-chain-1"
        
        # 正常模式：使用原有参数
        exec /beacon-chain \
            --datadir="$DATA_DIR" \
            --min-sync-peers=0 \
            --genesis-state="$GENESIS_FILE" \
            --bootstrap-node= \
            --interop-eth1data-votes \
            --chain-config-file="$CONFIG_FILE" \
            --contract-deployment-block=0 \
            --chain-id="${CHAIN_ID:-32382}" \
            --rpc-host=0.0.0.0 \
            --grpc-gateway-host=0.0.0.0 \
            --grpc-gateway-port=7777 \
            --execution-endpoint="$EXECUTION_ENDPOINT" \
            --accept-terms-of-use \
            --jwt-secret="$JWT_SECRET" \
            --suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524 \
            --minimum-peers-per-subnet=0 \
            --enable-debug-rpc-endpoints \
            --force-clear-db \
            --p2p-static-id=true \
            --p2p-max-peers=70 \
            --verbosity=debug \
            "$@"
    fi
}

# =============================================================================
# 脚本入口点
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 