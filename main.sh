#!/bin/bash
# =============================================================================
# 以太坊PoS测试网主启动脚本
# 
# 功能：
# - 启动完整的以太坊PoS测试网
# - 集成区块树可视化
# - 提供网络状态监控
# 
# 作者：AI Assistant
# 版本：2.0
# =============================================================================

set -euo pipefail  # 严格错误处理

# =============================================================================
# 配置常量
# =============================================================================
readonly BASE_IP="10.0.0"
readonly NS3_DIR="/home/ins0/Learning/Testnet/NS-3-Sim/ns-3.45"
readonly LOG_DIR="./logs"
readonly SIGNAL_DIR="./share/signals"
readonly CONTAINER_NAMES=("beacon-chain-1" "beacon-chain-2" "beacon-chain-3" "beacon-chain-4")
readonly CONTAINER_IPS=("10.0.0.1" "10.0.0.2" "10.0.0.3" "10.0.0.4")

# =============================================================================
# 颜色输出配置
# =============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'  # No Color

# =============================================================================
# 日志函数
# =============================================================================
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

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}[STEP]${NC} $1"
}

# =============================================================================
# 加载实现细节
# =============================================================================

# 获取脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 加载实现文件
if [ -f "$SCRIPT_DIR/implementation.sh" ]; then
    source "$SCRIPT_DIR/implementation.sh"
else
    log_error "实现文件 implementation.sh 不存在"
    exit 1
fi

# =============================================================================
# 显示使用帮助
# =============================================================================
show_usage() {
    cat << EOF
用法: $0 [选项]

选项:
  (无参数)   - 运行完整的以太坊PoS测试网设置
  clean      - 清理所有环境（容器、网络、数据、信号等）
  status     - 显示当前网络状态
  visualizer - 显示区块树可视化器状态
  help       - 显示此帮助信息

示例:
  $0           # 运行完整流程
  $0 clean     # 清理环境
  $0 status    # 查看状态
  $0 visualizer # 检查区块树可视化器

网络配置:
  - NS-3延迟: 1ms
  - 数据速率: 100Mbps
  - 节点数量: 4个beacon-chain
  - 网络拓扑: CSMA LAN

端口映射:
  - Geth RPC: localhost:8545
  - Beacon-1: localhost:7777
  - Beacon-2: localhost:7778
  - Beacon-3: localhost:7779
  - Beacon-4: localhost:7780
  - 区块树可视化: localhost:8888
  - Prometheus: localhost:9090
  - Grafana: localhost:3000

区块树可视化功能:
  🌐 实时区块树展示: http://localhost:8888
  📊 Grafana集成面板: http://localhost:3000
  📡 Fork Choice API: http://localhost:8888/api/fork-choice
  
  特性:
  - 动态更新区块结构
  - 分叉检测和展示
  - Justification/Finalization状态跟踪
  - 交互式可视化界面
EOF
}

# =============================================================================
# 核心执行流程
# =============================================================================

# 完整启动流程
run_full_setup() {
    log_info "🚀 开始执行以太坊PoS开发网络设置..."
    
    # 步骤0: 预检并清理残留
    preflight_clean_if_needed
    
    # 步骤1: 启动基础服务（包括区块树可视化器）
    build_containers
    
    # 步骤2: 设置网络
    setup_network
    
    # 步骤3: 运行NS-3网络模拟器
    run_ns3_simulator
    
    # 步骤4: 运行以太坊测试网
    run_ethereum_testnet
    
    # 步骤5: 运行区块树可视化器
    run_block_tree_visualizer
    
    # 显示最终状态
    show_network_status

    log_success "🎉 所有步骤执行完成！"
    
    echo -e "\n${GREEN}✅ 测试网已成功启动！${NC}"
    echo -e "\n${YELLOW}📋 快速访问链接：${NC}"
    echo -e "  🌐 区块树可视化: ${CYAN}http://localhost:8888${NC}"
    echo -e "  📊 Grafana仪表板: ${CYAN}http://localhost:3000${NC} (admin/admin)"
    echo -e "  📈 Prometheus监控: ${CYAN}http://localhost:9090${NC}"
    echo -e "  ⚡ Geth RPC接口: ${CYAN}http://localhost:8545${NC}"
    echo -e "\n${YELLOW}📖 使用指南：${NC}"
    echo -e "  • 查看状态: ${CYAN}./main.sh status${NC}"
    echo -e "  • 检查可视化器: ${CYAN}./main.sh visualizer${NC}"
    echo -e "  • 清理环境: ${CYAN}./main.sh clean${NC}"
}

# =============================================================================
# 主函数
# =============================================================================

main() {
    # 检查依赖（仅对需要的操作进行检查）
    case "${1:-}" in
        "help"|"-h"|"--help")
            show_usage
            return 0
            ;;
        *)
            check_command docker
            if ! docker compose version &>/dev/null; then
                log_error "docker compose 未找到，请先安装 Docker Compose"
                exit 1
            fi
            check_directory "$NS3_DIR"
            ;;
    esac
    
    case "${1:-}" in
        "clean")
            log_info "🧹 开始清理环境..."
            clean_all
            ;;
        "status")
            log_info "📊 显示网络状态..."
            show_network_status
            ;;
        "visualizer")
            log_info "🌐 检查区块树可视化器状态..."
            check_block_tree_visualizer_status
            ;;
        "")
            # 默认运行完整流程
            run_full_setup
            ;;
        *)
            log_error "未知选项: $1"
            show_usage
            exit 1
            ;;
    esac
}

# =============================================================================
# 脚本入口点
# =============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi