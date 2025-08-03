#!/bin/bash

# 多节点网络模拟脚本
# 支持创建任意n个节点并配置相应的虚拟设备

set -e

# 配置变量
# NODE_COUNT将在main函数中根据参数设置
BASE_IP="10.0.0"
SUBNET_MASK="16"
BRIDGE_PREFIX="br-node"
TAP_PREFIX="tap-node"
VETH_PREFIX="veth"
CONTAINER_PREFIX="node"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 函数：创建tap设备
create_tap_device() {
    local node_id=$1
    local tap_name="${TAP_PREFIX}-${node_id}"
    
    # 检查tap设备是否已存在
    if ip link show $tap_name >/dev/null 2>&1; then
        log_warning "tap设备 $tap_name 已存在，删除旧设备"
        sudo ip link del $tap_name 2>/dev/null || true
    fi
    
    log_info "创建tap设备: $tap_name"
    sudo ip tuntap add $tap_name mode tap
    sudo ip link set $tap_name promisc on
    sudo ip link set $tap_name up
}

# 函数：创建bridge
create_bridge() {
    local node_id=$1
    local bridge_name="${BRIDGE_PREFIX}-${node_id}"
    
    # 检查bridge是否已存在
    if ip link show $bridge_name >/dev/null 2>&1; then
        log_warning "bridge $bridge_name 已存在，删除旧bridge"
        sudo ip link del $bridge_name 2>/dev/null || true
    fi
    
    log_info "创建bridge: $bridge_name"
    sudo ip link add name $bridge_name type bridge
    sudo ip link set dev $bridge_name up
}

# 函数：配置iptables规则
configure_iptables() {
    local node_id=$1
    local bridge_name="${BRIDGE_PREFIX}-${node_id}"
    
    log_info "配置iptables规则: $bridge_name"
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -i $bridge_name -p tcp -j ACCEPT
    # 如果需要ARP支持，取消注释下面这行
    # sudo iptables -I FORWARD -m physdev --physdev-is-bridged -i $bridge_name -p arp -j ACCEPT
}

# 函数：启动Docker容器
start_containers() {
    log_info "启动Docker容器..."
    
    # 生成docker-compose.yml
    generate_docker_compose
    
    sudo docker compose -f docker-compose.yml up -d
    
    # 等待容器启动并检查状态
    log_info "等待容器启动..."
    local max_wait=30
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        local running_count=0
        for i in $(seq 1 $NODE_COUNT); do
            local container_name="${CONTAINER_PREFIX}-${i}"
            if sudo docker inspect --format '{{.State.Running}}' $container_name 2>/dev/null | grep -q "true"; then
                running_count=$((running_count + 1))
            fi
        done
        
        if [ $running_count -eq $NODE_COUNT ]; then
            log_success "所有容器已启动"
            break
        fi
        
        wait_count=$((wait_count + 1))
        sleep 1
    done
    
    if [ $wait_count -eq $max_wait ]; then
        log_error "容器启动超时"
        return 1
    fi
}

# 函数：生成docker-compose.yml
generate_docker_compose() {
    log_info "生成docker-compose.yml文件..."
    
    cat > docker-compose.yml << EOF
services:
EOF
    
    for i in $(seq 1 $NODE_COUNT); do
        cat >> docker-compose.yml << EOF
  ${CONTAINER_PREFIX}-${i}:
    image: ubuntu-net:latest
    container_name: ${CONTAINER_PREFIX}-${i}
    network_mode: "none"
    tty: true
EOF
    done
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
    local node_id=$1
    local container_name="${CONTAINER_PREFIX}-${node_id}"
    local bridge_name="${BRIDGE_PREFIX}-${node_id}"
    local veth_name="${VETH_PREFIX}-${node_id}"
    local pid=$(get_container_pid $container_name)
    local ip_addr="${BASE_IP}.${node_id}"
    local mac_addr="12:34:88:5D:61:$(printf "%02X" $node_id)"
    
    # 检查容器是否运行
    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        log_error "容器 $container_name 未运行或无法获取PID"
        return 1
    fi
    
    log_info "配置容器网络: $container_name (PID: $pid)"
    
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
    local node_id=$1
    local tap_name="${TAP_PREFIX}-${node_id}"
    local bridge_name="${BRIDGE_PREFIX}-${node_id}"
    
    log_info "连接tap设备到bridge: $tap_name -> $bridge_name"
    sudo ip link set $tap_name master $bridge_name
    sudo ip link set $tap_name up
}



# 函数：显示网络状态
show_network_status() {
    log_info "显示网络状态..."
    
    echo -e "\n${YELLOW}=== 网络设备状态 ===${NC}"
    sudo ip link show | grep -E "(br-node|tap-node|veth)"
    
    echo -e "\n${YELLOW}=== 容器状态 ===${NC}"
    sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n${YELLOW}=== 网络命名空间 ===${NC}"
    sudo ls -la /var/run/netns/
    
    echo -e "\n${YELLOW}=== iptables规则 ===${NC}"
    sudo iptables -L FORWARD -v -n | grep br-node
}

# 函数：测试网络连接
test_network_connectivity() {
    log_info "测试网络连接..."
    
    for i in $(seq 1 $NODE_COUNT); do
        local container_name="${CONTAINER_PREFIX}-${i}"
        local target_ip="${BASE_IP}.$((i % NODE_COUNT + 1))"
        
        if [ "$i" -eq "$NODE_COUNT" ]; then
            target_ip="${BASE_IP}.1"
        fi
        
        log_info "测试 $container_name -> $target_ip"
        sudo docker exec $container_name ping -c 2 $target_ip || log_warning "ping失败: $container_name -> $target_ip"
    done
}

# 函数：清理网络
cleanup_network() {
    log_info "清理网络资源..."
    
    # 停止容器
    sudo docker compose -f docker-compose.yml down 2>/dev/null || true
    
    # 清理网络设备 - 使用更安全的方式
    local max_nodes=50  # 最大清理50个节点
    for i in $(seq 1 $max_nodes); do
        local bridge_name="${BRIDGE_PREFIX}-${i}"
        local tap_name="${TAP_PREFIX}-${i}"
        
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
    # 删除所有与br-node相关的iptables规则
    local rule_num=1
    while true; do
        # 查找包含br-node的FORWARD规则
        local rule_line=$(sudo iptables -L FORWARD -v -n --line-numbers | grep br-node | head -1 | awk '{print $1}')
        if [ -z "$rule_line" ]; then
            break  # 没有找到更多规则
        fi
        log_info "删除iptables规则 #$rule_line"
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
    # 设置节点数量
    NODE_COUNT=${2:-2}  # 默认2个节点，可通过第二个参数指定
    
    log_info "开始创建 $NODE_COUNT 个节点的网络环境..."
    
    # 检查参数
    if [ "$NODE_COUNT" -lt 1 ] || [ "$NODE_COUNT" -gt 254 ]; then
        log_error "节点数量必须在1-254之间"
        exit 1
    fi
    
    # 清理可能存在的旧配置
    cleanup_network
    
    # 第一步：启动容器（必须先启动容器才能获取PID）
    log_info "第一步：启动Docker容器..."
    if ! start_containers; then
        log_error "容器启动失败"
        exit 1
    fi
    
    # 第二步：创建网络设备（tap、bridge、iptables）
    log_info "第二步：创建网络设备..."
    for i in $(seq 1 $NODE_COUNT); do
        create_tap_device $i
        create_bridge $i
        configure_iptables $i
    done
    
    # 第三步：配置容器网络（需要容器PID）
    log_info "第三步：配置容器网络..."
    for i in $(seq 1 $NODE_COUNT); do
        if ! setup_network_namespace "${CONTAINER_PREFIX}-${i}"; then
            log_error "设置网络命名空间失败: ${CONTAINER_PREFIX}-${i}"
            continue
        fi
        
        if ! configure_container_network $i; then
            log_error "配置容器网络失败: ${CONTAINER_PREFIX}-${i}"
            continue
        fi
    done
    
    # 第四步：连接tap到bridge
    log_info "第四步：连接tap设备到bridge..."
    for i in $(seq 1 $NODE_COUNT); do
        connect_tap_to_bridge $i
    done
    
    # 显示状态
    show_network_status
    
    # 测试连接
    test_network_connectivity
    
    log_success "多节点网络环境创建完成！"
    log_info "使用以下命令进入容器:"
    for i in $(seq 1 $NODE_COUNT); do
        echo "  sudo docker exec -it ${CONTAINER_PREFIX}-${i} bash"
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