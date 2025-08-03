#!/bin/bash

# 集成模拟脚本：多节点网络 + NS-3模拟

set -e

# 配置变量
NODE_COUNT=${1:-2}
SIMULATION_TIME=${2:-600}
DATA_RATE=${3:-"100Mbps"}
DELAY=${4:-"6560ns"}
NS3_DIR="/home/ins0/Learning/Testnet/NS-3-Sim/ns-3.45"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 清理函数
cleanup() {
    log_info "清理资源..."
    ./multi-node-network.sh clean
    log_success "清理完成"
}

# 信号处理
trap cleanup EXIT INT TERM

# 主函数
main() {
    log_info "开始集成模拟..."
    log_info "节点数量: $NODE_COUNT"
    log_info "模拟时间: $SIMULATION_TIME 秒"
    log_info "数据速率: $DATA_RATE"
    log_info "延迟: $DELAY"

    # 第一步：创建多节点网络环境
    log_info "第一步：创建多节点网络环境..."
    ./multi-node-network.sh setup $NODE_COUNT
    
    if [ $? -ne 0 ]; then
        log_error "网络环境创建失败"
        exit 1
    fi
    
    log_success "网络环境创建完成"

    # 第二步：复制NS-3场景文件
    log_info "第二步：准备NS-3场景文件..."
    if [ ! -f "src/multi-node-tap-scenario.cc" ]; then
        log_error "NS-3场景文件不存在"
        exit 1
    fi
    
    cp src/multi-node-tap-scenario.cc "$NS3_DIR/scratch/"
    log_success "NS-3场景文件已复制"

    # 第三步：运行NS-3模拟
    log_info "第三步：启动NS-3模拟..."
    ./run-ns3-simulation.sh $NODE_COUNT $SIMULATION_TIME "$DATA_RATE" "$DELAY"
    
    if [ $? -ne 0 ]; then
        log_error "NS-3模拟失败"
        exit 1
    fi
    
    log_success "NS-3模拟完成"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [节点数量] [模拟时间] [数据速率] [延迟]"
    echo ""
    echo "参数:"
    echo "  节点数量     - 要创建的节点数量 (默认: 2)"
    echo "  模拟时间     - 模拟运行时间(秒) (默认: 600)"
    echo "  数据速率     - CSMA通道数据速率 (默认: 100Mbps)"
    echo "  延迟         - CSMA通道延迟 (默认: 6560ns)"
    echo ""
    echo "示例:"
    echo "  $0                    # 使用默认参数"
    echo "  $0 5                 # 创建5个节点"
    echo "  $0 3 300             # 3个节点，运行5分钟"
    echo "  $0 4 600 1Gbps 100ns # 4个节点，1Gbps，100ns延迟"
    echo ""
    echo "注意: 脚本会自动清理资源，按Ctrl+C可以提前终止"
}

# 检查参数
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

# 验证参数
if [ "$NODE_COUNT" -lt 1 ] || [ "$NODE_COUNT" -gt 50 ]; then
    log_error "节点数量必须在1-50之间"
    exit 1
fi

if [ "$SIMULATION_TIME" -lt 1 ]; then
    log_error "模拟时间必须大于0"
    exit 1
fi

# 运行主函数
main

log_success "集成模拟完成！" 