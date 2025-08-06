#!/bin/bash

# beacon-chain网络验证脚本
# 验证tap设备、容器和IP地址的正确映射

set -e

# 配置变量
DOCKER_COMPOSE_FILE="../docker-compose-for-ns3.yml"
BASE_IP="10.0.0"

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

# 验证docker-compose文件
verify_compose_file() {
    log_info "验证docker-compose文件..."
    
    if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
        log_error "Docker-compose文件不存在: $DOCKER_COMPOSE_FILE"
        return 1
    fi
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local service_count=$(echo "$beacon_services" | wc -w)
    
    log_success "发现 $service_count 个beacon-chain服务:"
    for service in $beacon_services; do
        echo "  - $service"
    done
    
    return 0
}

# 验证tap设备
verify_tap_devices() {
    log_info "验证tap设备..."
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local missing_taps=0
    
    for service in $beacon_services; do
        local node_suffix=$(echo $service | sed 's/beacon-chain-//')
        local tap_name="tap-beacon-${node_suffix}"
        
        if ip link show $tap_name >/dev/null 2>&1; then
            log_success "tap设备存在: $tap_name"
        else
            log_error "tap设备缺失: $tap_name"
            missing_taps=$((missing_taps + 1))
        fi
    done
    
    if [ $missing_taps -eq 0 ]; then
        log_success "所有tap设备验证通过"
        return 0
    else
        log_error "$missing_taps 个tap设备缺失"
        return 1
    fi
}

# 验证bridge设备
verify_bridge_devices() {
    log_info "验证bridge设备..."
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local missing_bridges=0
    
    for service in $beacon_services; do
        local node_suffix=$(echo $service | sed 's/beacon-chain-//')
        local bridge_name="br-beacon-${node_suffix}"
        
        if ip link show $bridge_name >/dev/null 2>&1; then
            log_success "bridge设备存在: $bridge_name"
        else
            log_error "bridge设备缺失: $bridge_name"
            missing_bridges=$((missing_bridges + 1))
        fi
    done
    
    if [ $missing_bridges -eq 0 ]; then
        log_success "所有bridge设备验证通过"
        return 0
    else
        log_error "$missing_bridges 个bridge设备缺失"
        return 1
    fi
}

# 验证容器状态
verify_containers() {
    log_info "验证容器状态..."
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local not_running=0
    
    for service in $beacon_services; do
        if sudo docker inspect --format '{{.State.Running}}' "$service" 2>/dev/null | grep -q "true"; then
            log_success "容器运行中: $service"
        else
            log_error "容器未运行: $service"
            not_running=$((not_running + 1))
        fi
    done
    
    if [ $not_running -eq 0 ]; then
        log_success "所有容器验证通过"
        return 0
    else
        log_error "$not_running 个容器未运行"
        return 1
    fi
}

# 验证容器IP配置
verify_container_ips() {
    log_info "验证容器IP配置..."
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local ip_errors=0
    local index=1
    
    for service in $beacon_services; do
        local expected_ip="${BASE_IP}.${index}"
        
        # 检查容器是否有eth0接口和正确的IP
        local container_ip=$(sudo docker exec "$service" ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "")
        
        if [ "$container_ip" = "$expected_ip" ]; then
            log_success "容器IP正确: $service -> $container_ip"
        else
            log_error "容器IP错误: $service (期望: $expected_ip, 实际: $container_ip)"
            ip_errors=$((ip_errors + 1))
        fi
        
        index=$((index + 1))
    done
    
    if [ $ip_errors -eq 0 ]; then
        log_success "所有容器IP验证通过"
        return 0
    else
        log_error "$ip_errors 个容器IP配置错误"
        return 1
    fi
}

# 验证网络连通性
verify_network_connectivity() {
    log_info "验证网络连通性..."
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local services_array=($beacon_services)
    local service_count=${#services_array[@]}
    local connectivity_errors=0
    
    for i in $(seq 0 $((service_count - 1))); do
        local current_service="${services_array[$i]}"
        local next_index=$(((i + 1) % service_count))
        local target_service="${services_array[$next_index]}"
        local target_ip="${BASE_IP}.$((next_index + 1))"
        
        log_info "测试连接: $current_service -> $target_service ($target_ip)"
        
        if sudo docker exec "$current_service" ping -c 2 -W 3 "$target_ip" >/dev/null 2>&1; then
            log_success "连接成功: $current_service -> $target_service"
        else
            log_error "连接失败: $current_service -> $target_service"
            connectivity_errors=$((connectivity_errors + 1))
        fi
    done
    
    if [ $connectivity_errors -eq 0 ]; then
        log_success "所有网络连接验证通过"
        return 0
    else
        log_error "$connectivity_errors 个网络连接失败"
        return 1
    fi
}

# 显示网络拓扑
show_network_topology() {
    log_info "显示网络拓扑..."
    
    local beacon_services=$(grep -E "^\s*beacon-chain-[0-9]+:" "$DOCKER_COMPOSE_FILE" | sed 's/://g' | awk '{print $1}')
    local index=1
    
    echo ""
    echo -e "${YELLOW}=== beacon-chain网络拓扑 ===${NC}"
    echo ""
    
    for service in $beacon_services; do
        local node_suffix=$(echo $service | sed 's/beacon-chain-//')
        local tap_name="tap-beacon-${node_suffix}"
        local bridge_name="br-beacon-${node_suffix}"
        local ip_addr="${BASE_IP}.${index}"
        
        echo -e "节点 ${index}:"
        echo -e "  容器: ${GREEN}$service${NC}"
        echo -e "  IP地址: ${BLUE}$ip_addr${NC}"
        echo -e "  tap设备: $tap_name"
        echo -e "  bridge: $bridge_name"
        echo ""
        
        index=$((index + 1))
    done
}

# 主函数
main() {
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}       beacon-chain网络验证脚本${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo ""
    
    local total_errors=0
    
    # 执行所有验证
    verify_compose_file || total_errors=$((total_errors + 1))
    echo ""
    
    verify_tap_devices || total_errors=$((total_errors + 1))
    echo ""
    
    verify_bridge_devices || total_errors=$((total_errors + 1))
    echo ""
    
    verify_containers || total_errors=$((total_errors + 1))
    echo ""
    
    verify_container_ips || total_errors=$((total_errors + 1))
    echo ""
    
    verify_network_connectivity || total_errors=$((total_errors + 1))
    echo ""
    
    # 显示拓扑
    show_network_topology
    
    # 总结
    echo -e "${BLUE}================================================${NC}"
    if [ $total_errors -eq 0 ]; then
        log_success "所有验证通过！beacon-chain网络配置正确"
        echo -e "${GREEN}✅ 系统就绪，可以运行NS-3仿真${NC}"
    else
        log_error "发现 $total_errors 个问题，请检查网络配置"
        echo -e "${RED}❌ 请修复问题后再运行NS-3仿真${NC}"
    fi
    echo -e "${BLUE}================================================${NC}"
    
    return $total_errors
}

# 运行主函数
main "$@"