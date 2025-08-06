#!/bin/bash

# 多节点网络模拟脚本
# 支持创建任意n个节点并配置相应的虚拟设备

set -e

# 配置变量
# BEACON_SERVICES将在解析yml文件后填充
BASE_IP="10.0.0"
SUBNET_MASK="16"
BRIDGE_PREFIX="br-beacon"
TAP_PREFIX="tap-beacon"
VETH_PREFIX="veth-beacon"
CONTAINER_PREFIX="beacon-chain"
DOCKER_COMPOSE_FILE="../docker-compose-for-ns3.yml"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 全局变量
declare -a BEACON_SERVICES=()
declare -a BEACON_IPS=()

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

# 函数：解析docker-compose文件并提取beacon-chain服务
parse_beacon_services() {
    log_info "解析docker-compose文件: $DOCKER_COMPOSE_FILE"
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker-compose文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    # 使用grep和awk提取beacon-chain服务名称
    local services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    
    if [ -z "$services" ]; then
        log_error "未找到beacon-chain服务"
        return 1
    fi
    
    # 清空并重新填充数组
    BEACON_SERVICES=()
    BEACON_IPS=()
    
    local index=1
    for service in $services; do
        BEACON_SERVICES+=("$service")
        BEACON_IPS+=("${BASE_IP}.${index}")
        log_info "发现beacon-chain服务: $service -> ${BASE_IP}.${index}"
        index=$((index + 1))
    done
    
    log_success "解析完成，共发现 ${#BEACON_SERVICES[@]} 个beacon-chain服务"
    return 0
}

# 函数：创建tap设备
create_tap_device() {
    local service_name=$1
    local tap_name="${TAP_PREFIX}-$(echo $service_name | sed 's/beacon-chain-//')"
    
    # 检查tap设备是否已存在
    if ip link show $tap_name >/dev/null 2>&1; then
        log_warning "tap设备 $tap_name 已存在，删除旧设备"
        sudo ip link del $tap_name 2>/dev/null || true
    fi
    
    log_info "为服务 $service_name 创建tap设备: $tap_name"
    sudo ip tuntap add $tap_name mode tap
    sudo ip link set $tap_name promisc on
    sudo ip link set $tap_name up
}

# 函数：创建bridge
create_bridge() {
    local service_name=$1
    local bridge_name="${BRIDGE_PREFIX}-$(echo $service_name | sed 's/beacon-chain-//')"
    
    # 检查bridge是否已存在
    if ip link show $bridge_name >/dev/null 2>&1; then
        log_warning "bridge $bridge_name 已存在，删除旧bridge"
        sudo ip link del $bridge_name 2>/dev/null || true
    fi
    
    log_info "为服务 $service_name 创建bridge: $bridge_name"
    sudo ip link add name $bridge_name type bridge
    sudo ip link set dev $bridge_name up
}

# 函数：配置iptables规则
configure_iptables() {
    local service_name=$1
    local bridge_name="${BRIDGE_PREFIX}-$(echo $service_name | sed 's/beacon-chain-//')"
    
    log_info "为服务 $service_name 配置iptables规则: $bridge_name"
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -i $bridge_name -p tcp -j ACCEPT
    # 如果需要ARP支持，取消注释下面这行
    # sudo iptables -I FORWARD -m physdev --physdev-is-bridged -i $bridge_name -p arp -j ACCEPT
}

# 函数：启动Docker容器
start_containers() {
    log_info "使用现有的docker-compose文件启动容器..."
    
    # 使用现有的docker-compose文件
    sudo docker compose -f "$DOCKER_COMPOSE_FILE" up -d
    
    # 等待beacon-chain容器启动并检查状态
    log_info "等待beacon-chain容器启动..."
    local max_wait=60
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        local running_count=0
        for service in "${BEACON_SERVICES[@]}"; do
            if sudo docker inspect --format '{{.State.Running}}' "$service" 2>/dev/null | grep -q "true"; then
                running_count=$((running_count + 1))
            fi
        done
        
        if [ $running_count -eq ${#BEACON_SERVICES[@]} ]; then
            log_success "所有beacon-chain容器已启动"
            break
        fi
        
        wait_count=$((wait_count + 1))
        sleep 2
    done
    
    if [ $wait_count -eq $max_wait ]; then
        log_error "beacon-chain容器启动超时"
        return 1
    fi
}



# 函数：获取容器PID
get_container_pid() {
    local container_name=$1
    sudo docker inspect --format '{{ .State.Pid }}' $container_name
}

# 函数：设置网络命名空间
setup_network_namespace() {
    local container_name=$1
    local pid=$(get_container_pid $container_name)
    
    # 检查容器是否运行
    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        log_error "容器 $container_name 未运行或无法获取PID"
        return 1
    fi
    
    log_info "设置网络命名空间: $container_name (PID: $pid)"
    
    # 只在第一次调用时创建目录
    if [ ! -d "/var/run/netns" ]; then
        sudo mkdir -p /var/run/netns
    fi
    
    # 检查网络命名空间是否已经存在
    if [ ! -L "/var/run/netns/$pid" ]; then
        sudo ln -sf /proc/$pid/ns/net /var/run/netns/$pid
    else
        log_info "网络命名空间 $pid 已存在"
    fi
}

# 函数：配置容器网络
configure_container_network() {
    local service_name=$1
    local index=$2
    local container_name="$service_name"
    local node_suffix=$(echo $service_name | sed 's/beacon-chain-//')
    local bridge_name="${BRIDGE_PREFIX}-${node_suffix}"
    local veth_name="${VETH_PREFIX}-${node_suffix}"
    local pid=$(get_container_pid $container_name)
    local ip_addr="${BEACON_IPS[$((index-1))]}"
    local mac_addr="12:34:88:5D:61:$(printf "%02X" $index)"
    
    # 检查容器是否运行
    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        log_error "容器 $container_name 未运行或无法获取PID"
        return 1
    fi
    
    log_info "配置容器网络: $container_name (PID: $pid) -> $ip_addr"
    
    # 创建veth pair
    sudo ip link add ${veth_name}-in type veth peer name ${veth_name}-ex
    
    # 配置bridge端
    sudo ip link set ${veth_name}-in master $bridge_name
    sudo ip link set ${veth_name}-in up
    
    # 配置容器端
    sudo ip link set ${veth_name}-ex netns $pid
    sudo ip netns exec $pid ip link set dev ${veth_name}-ex name eth0
    sudo ip netns exec $pid ip link set eth0 address $mac_addr
    sudo ip netns exec $pid ip link set eth0 up
    sudo ip netns exec $pid ip addr add ${ip_addr}/${SUBNET_MASK} dev eth0
    
    log_info "容器网络配置完成: $container_name -> $ip_addr"
}

# 函数：连接tap设备到bridge
connect_tap_to_bridge() {
    local service_name=$1
    local node_suffix=$(echo $service_name | sed 's/beacon-chain-//')
    local tap_name="${TAP_PREFIX}-${node_suffix}"
    local bridge_name="${BRIDGE_PREFIX}-${node_suffix}"
    
    log_info "连接tap设备到bridge: $tap_name -> $bridge_name (服务: $service_name)"
    sudo ip link set $tap_name master $bridge_name
    sudo ip link set $tap_name up
}



# 函数：显示网络状态
show_network_status() {
    log_info "显示网络状态..."
    
    echo -e "\n${YELLOW}=== 网络设备状态 ===${NC}"
    sudo ip link show | grep -E "(br-beacon|tap-beacon|veth-beacon)"
    
    echo -e "\n${YELLOW}=== beacon-chain容器状态 ===${NC}"
    for service in "${BEACON_SERVICES[@]}"; do
        echo -n "$service: "
        sudo docker inspect --format '{{.State.Status}}' "$service" 2>/dev/null || echo "未找到"
    done
    
    echo -e "\n${YELLOW}=== 网络命名空间 ===${NC}"
    sudo ls -la /var/run/netns/ 2>/dev/null || echo "无网络命名空间"
    
    echo -e "\n${YELLOW}=== iptables规则 ===${NC}"
    sudo iptables -L FORWARD -v -n | grep br-beacon
}

# 函数：测试网络连接
test_network_connectivity() {
    log_info "测试beacon-chain节点间网络连接..."
    
    local service_count=${#BEACON_SERVICES[@]}
    for i in $(seq 0 $((service_count - 1))); do
        local current_service="${BEACON_SERVICES[$i]}"
        local current_ip="${BEACON_IPS[$i]}"
        
        # 测试连接到下一个节点
        local next_index=$(((i + 1) % service_count))
        local target_ip="${BEACON_IPS[$next_index]}"
        local target_service="${BEACON_SERVICES[$next_index]}"
        
        log_info "测试连接: $current_service ($current_ip) -> $target_service ($target_ip)"
        sudo docker exec $current_service ping -c 2 $target_ip || log_warning "ping失败: $current_service -> $target_service"
    done
}

# 函数：清理网络
cleanup_network() {
    log_info "清理网络资源..."
    
    # 停止容器
    sudo docker compose -f "$DOCKER_COMPOSE_FILE" down 2>/dev/null || true
    
    # 清理网络设备 - 清理所有br-beacon和tap-beacon设备
    log_info "清理beacon相关网络设备..."
    local beacon_bridges=$(ip link show | grep -o "br-beacon-[0-9]*" | head -20)
    local beacon_taps=$(ip link show | grep -o "tap-beacon-[0-9]*" | head -20)
    
    # 清理bridge设备
    for bridge_name in $beacon_bridges; do
        if ip link show $bridge_name >/dev/null 2>&1; then
            log_info "清理bridge: $bridge_name"
            # 删除bridge
            sudo ip link del $bridge_name 2>/dev/null || true
        fi
    done
    
    # 清理tap设备
    for tap_name in $beacon_taps; do
        if ip link show $tap_name >/dev/null 2>&1; then
            log_info "清理tap: $tap_name"
            sudo ip link del $tap_name 2>/dev/null || true
        fi
    done
    
    # 清理veth设备
    local beacon_veths=$(ip link show | grep -o "veth-beacon-[0-9]*-in" | head -20)
    for veth_name in $beacon_veths; do
        local base_name=$(echo $veth_name | sed 's/-in$//')
        if ip link show $veth_name >/dev/null 2>&1; then
            log_info "清理veth: $base_name"
            sudo ip link del $veth_name 2>/dev/null || true
        fi
    done
    
    # 兼容旧的命名规范
    local max_nodes=50  # 最大清理50个节点
    for i in $(seq 1 $max_nodes); do
        local bridge_name="br-node-${i}"
        local tap_name="tap-node-${i}"
        
        # 检查设备是否存在，如果存在则清理
        if ip link show $bridge_name >/dev/null 2>&1; then
            log_info "清理bridge: $bridge_name"
            # 从bridge移除tap
            sudo ip link set $tap_name nomaster 2>/dev/null || true
            # 删除bridge
            sudo ip link del $bridge_name 2>/dev/null || true
        fi
        
        if ip link show $tap_name >/dev/null 2>&1; then
            log_info "清理tap: $tap_name"
            # 删除tap
            sudo ip link del $tap_name 2>/dev/null || true
        fi
        
        # 清理veth设备
        local veth_name="${VETH_PREFIX}-${i}"
        if ip link show ${veth_name}-in >/dev/null 2>&1; then
            log_info "清理veth: ${veth_name}-in"
            sudo ip link del ${veth_name}-in 2>/dev/null || true
        fi
    done
    
    # 清理iptables规则
    log_info "清理iptables规则..."
    # 删除所有与br-beacon相关的iptables规则
    local rule_num=1
    while true; do
        # 查找包含br-beacon的FORWARD规则
        local rule_line=$(sudo iptables -L FORWARD -v -n --line-numbers | grep br-beacon | head -1 | awk '{print $1}')
        if [ -z "$rule_line" ]; then
            break  # 没有找到更多规则
        fi
        log_info "删除iptables规则 #$rule_line"
        sudo iptables -D FORWARD $rule_line 2>/dev/null || true
    done
    
    # 兼容清理旧的br-node规则
    while true; do
        local rule_line=$(sudo iptables -L FORWARD -v -n --line-numbers | grep br-node | head -1 | awk '{print $1}')
        if [ -z "$rule_line" ]; then
            break
        fi
        log_info "删除旧的br-node iptables规则 #$rule_line"
        sudo iptables -D FORWARD $rule_line 2>/dev/null || true
    done
    
    # 清理网络命名空间
    sudo rm -rf /var/run/netns
    
    log_success "网络清理完成"
}

# 函数：清理iptables规则
cleanup_iptables() {
    log_info "清理iptables规则..."
    
    # 方法1：删除所有与br-node相关的规则
    local cleaned_count=0
    while true; do
        # 查找包含br-node的FORWARD规则
        local rule_line=$(sudo iptables -L FORWARD -v -n --line-numbers 2>/dev/null | grep br-node | head -1 | awk '{print $1}')
        if [ -z "$rule_line" ] || [ "$rule_line" = "" ]; then
            break  # 没有找到更多规则
        fi
        log_info "删除iptables规则 #$rule_line"
        sudo iptables -D FORWARD $rule_line 2>/dev/null || true
        cleaned_count=$((cleaned_count + 1))
    done
    
    # 方法2：删除所有与physdev相关的规则（备用方法）
    local physdev_count=0
    while true; do
        local rule_line=$(sudo iptables -L FORWARD -v -n --line-numbers 2>/dev/null | grep physdev | head -1 | awk '{print $1}')
        if [ -z "$rule_line" ] || [ "$rule_line" = "" ]; then
            break
        fi
        log_info "删除physdev规则 #$rule_line"
        sudo iptables -D FORWARD $rule_line 2>/dev/null || true
        physdev_count=$((physdev_count + 1))
    done
    
    log_success "iptables清理完成: 删除 $cleaned_count 个br-node规则, $physdev_count 个physdev规则"
}

# 主函数
main() {
    log_info "开始为beacon-chain节点创建NS-3网络环境..."
    
    # 第一步：解析docker-compose文件
    log_info "第一步：解析docker-compose文件..."
    if ! parse_beacon_services; then
        log_error "解析docker-compose文件失败"
        exit 1
    fi
    
    local service_count=${#BEACON_SERVICES[@]}
    if [ "$service_count" -eq 0 ]; then
        log_error "未找到beacon-chain服务"
        exit 1
    fi
    
    # 清理可能存在的旧配置
    cleanup_network
    
    # 第二步：启动容器（必须先启动容器才能获取PID）
    log_info "第二步：启动Docker容器..."
    if ! start_containers; then
        log_error "容器启动失败"
        exit 1
    fi
    
    # 第三步：创建网络设备（tap、bridge、iptables）
    log_info "第三步：为beacon-chain服务创建网络设备..."
    for service in "${BEACON_SERVICES[@]}"; do
        create_tap_device "$service"
        create_bridge "$service"
        configure_iptables "$service"
    done
    
    # 第四步：配置容器网络（需要容器PID）
    log_info "第四步：配置beacon-chain容器网络..."
    local index=1
    for service in "${BEACON_SERVICES[@]}"; do
        if ! setup_network_namespace "$service"; then
            log_error "设置网络命名空间失败: $service"
            continue
        fi
        
        if ! configure_container_network "$service" "$index"; then
            log_error "配置容器网络失败: $service"
            continue
        fi
        index=$((index + 1))
    done
    
    # 第五步：连接tap到bridge
    log_info "第五步：连接tap设备到bridge..."
    for service in "${BEACON_SERVICES[@]}"; do
        connect_tap_to_bridge "$service"
    done
    
    # 显示状态
    show_network_status
    
    # 测试连接
    test_network_connectivity
    
    log_success "beacon-chain网络环境创建完成！"
    log_info "beacon-chain服务及其IP地址:"
    for i in $(seq 0 $((service_count - 1))); do
        echo "  ${BEACON_SERVICES[$i]} -> ${BEACON_IPS[$i]}"
    done
    log_info "使用以下命令进入容器:"
    for service in "${BEACON_SERVICES[@]}"; do
        echo "  sudo docker exec -it $service bash"
    done
}

# 脚本入口
case "${1:-setup}" in
    "setup")
        main
        ;;
    "clean")
        cleanup_network
        ;;
    "clean-iptables")
        cleanup_iptables
        ;;
    "status")
        show_network_status
        ;;
    "test")
        test_network_connectivity
        ;;
    *)
        echo "用法: $0 [setup|clean|clean-iptables|status|test] [节点数量]"
        echo "  setup         - 创建网络环境 (默认)"
        echo "  clean         - 清理网络环境"
        echo "  clean-iptables - 仅清理iptables规则"
        echo "  status        - 显示网络状态"
        echo "  test          - 测试网络连接"
        echo "  节点数量      - 指定要创建的节点数量 (默认2)"
        echo ""
        echo "示例:"
        echo "  $0 setup        # 创建2个节点"
        echo "  $0 setup 5      # 创建5个节点"
        echo "  $0 clean        # 清理所有网络资源"
        echo "  $0 clean-iptables # 仅清理iptables规则"
        echo "  $0 status       # 查看状态"
        echo "  $0 test         # 测试连接"
        exit 1
        ;;
esac 