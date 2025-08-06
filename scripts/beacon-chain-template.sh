#!/bin/bash
# =============================================================================
# Beacon Chain 启动脚本模板
# 
# 使用方法：
# 1. 复制此模板到具体节点脚本
# 2. 修改 NODE_ID, NODE_IP, API_PORT 等变量
# 3. 根据需要调整bootstrap节点配置
# 
# 功能：
# - 支持NS-3网络集成模式
# - 等待网络就绪信号
# - 自动获取bootstrap节点信息
# 
# 作者：AI Assistant
# 版本：2.0
# =============================================================================

set -euo pipefail  # 严格错误处理

# =============================================================================
# 配置常量 (需要根据具体节点修改)
# =============================================================================
readonly NODE_ID="X"                    # 节点ID (1, 2, 3, 4)
readonly NODE_IP="10.0.0.X"            # NS-3 IP地址
readonly API_PORT="777X"                # API端口
readonly SIGNAL_DIR="/share/signals"
readonly BOOTSTRAP_FILE="/share/bootstrap_enr.txt"
readonly DATA_DIR="/consensus/beacondataX"
readonly CONFIG_FILE="/config/config-X.yml"
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

# 读取 bootstrap 节点信息
get_bootstrap_node() {
    if [ -f "$BOOTSTRAP_FILE" ]; then
        cat "$BOOTSTRAP_FILE"
    else
        log_warning "Bootstrap文件不存在: $BOOTSTRAP_FILE"
        echo ""
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
    log_info "Beacon Chain $NODE_ID 启动脚本开始执行"
    
    # 检查必要文件
    if ! check_required_files; then
        log_error "文件检查失败，退出"
        exit 1
    fi
    
    # 检查运行模式
    if [ "${NS3_INTEGRATION:-false}" = "true" ]; then
        log_info "NS-3 集成模式启动 beacon-chain-$NODE_ID"
        
        # 等待 NS-3 网络配置完成
        if ! wait_for_signal "ns3_network_ready.lock"; then
            log_error "NS-3网络就绪信号超时"
            exit 1
        fi
        
        # 等待 bootstrap 信息就绪 (非第一个节点)
        if [ "$NODE_ID" != "1" ]; then
            if ! wait_for_signal "bootstrap_ready.lock"; then
                log_error "Bootstrap就绪信号超时"
                exit 1
            fi
        fi
        
        # 等待网络启动许可 (非第一个节点)
        if [ "$NODE_ID" != "1" ]; then
            if ! wait_for_signal "network_ready.lock"; then
                log_error "网络启动信号超时"
                exit 1
            fi
        fi
        
        log_info "信号检查完成，启动 beacon-chain-$NODE_ID..."
        
        # 获取 bootstrap 节点信息
        local bootstrap_node=""
        if [ "$NODE_ID" != "1" ]; then
            bootstrap_node=$(get_bootstrap_node)
            log_info "Bootstrap 节点: $bootstrap_node"
        fi
        
        # NS-3 集成模式：使用指定的 IP 地址
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
        log_info "正常模式启动 beacon-chain-$NODE_ID"
        
        # 获取 bootstrap 节点信息
        local bootstrap_node=$(get_bootstrap_node)
        
        # 正常模式：使用原有参数
        exec /beacon-chain \
            --datadir="$DATA_DIR" \
            --min-sync-peers=0 \
            --genesis-state="$GENESIS_FILE" \
            --bootstrap-node="$bootstrap_node" \
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