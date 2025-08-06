#!/bin/bash

# NS-3多节点模拟运行脚本

set -e

# 配置变量
NS3_DIR="/home/ins0/Learning/Testnet/NS-3-Sim/ns-3.45"
SCENARIO_NAME="multi-node-tap-scenario"
NODE_COUNT=${1:-2}
SIMULATION_TIME=${2:-600}
DATA_RATE=${3:-"100Mbps"}
DELAY=${4:-"6560ns"}

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

# 检查NS-3目录是否存在
if [ ! -d "$NS3_DIR" ]; then
    log_error "NS-3目录不存在: $NS3_DIR"
    exit 1
fi

# 检查场景文件是否存在
SCENARIO_FILE="$NS3_DIR/scratch/$SCENARIO_NAME.cc"
if [ ! -f "$SCENARIO_FILE" ]; then
    log_error "场景文件不存在: $SCENARIO_FILE"
    exit 1
fi

log_info "开始NS-3多节点模拟..."
log_info "节点数量: $NODE_COUNT"
log_info "模拟时间: $SIMULATION_TIME 秒"
log_info "数据速率: $DATA_RATE"
log_info "延迟: $DELAY"

# 切换到NS-3目录
cd "$NS3_DIR"

# 检查是否需要编译
if [ ! -f "build/scratch/$SCENARIO_NAME" ]; then
    log_info "编译NS-3场景..."
    ./ns3 build scratch/$SCENARIO_NAME
    if [ $? -ne 0 ]; then
        log_error "编译失败"
        exit 1
    fi
    log_success "编译完成"
else
    log_info "使用已编译的场景"
fi

# 运行模拟
log_info "启动NS-3模拟..."
log_info "命令: ./ns3 run scratch/$SCENARIO_NAME -- --nNodes=$NODE_COUNT --simulationTime=$SIMULATION_TIME --dataRate=$DATA_RATE --delay=$DELAY --verbose"

./ns3 run scratch/$SCENARIO_NAME -- \
    --nNodes=$NODE_COUNT \
    --simulationTime=$SIMULATION_TIME \
    --dataRate="$DATA_RATE" \
    --delay="$DELAY" \
    --verbose

if [ $? -eq 0 ]; then
    log_success "NS-3模拟完成"
else
    log_error "NS-3模拟失败"
    exit 1
fi 