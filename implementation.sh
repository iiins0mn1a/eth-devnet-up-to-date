#!/bin/bash
# =============================================================================
# 以太坊PoS测试网实现细节和工具函数
# 
# 本文件包含所有的实现细节，被main.sh调用
# 功能：
# - 工具函数和检查函数
# - 网络管理详细实现
# - 服务启动和状态检查
# - 清理和维护功能
# 
# 作者：AI Assistant
# 版本：2.0
# =============================================================================

# 禁止直接执行此文件
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "错误：此文件不能直接执行，请通过 main.sh 调用"
    exit 1
fi

# =============================================================================
# 工具函数
# =============================================================================

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "命令 '$1' 未找到，请先安装"
        exit 1
    fi
}

# 检查目录是否存在
check_directory() {
    if [ ! -d "$1" ]; then
        log_error "目录 '$1' 不存在"
        exit 1
    fi
}

# 检测是否存在残留数据/容器/信号
has_dirty_state() {
    local dirty=false

    # 1) 运行中的相关容器
    if docker compose ps -q | grep -q . 2>/dev/null; then
        dirty=true
    fi

    # 2) 执行层/共识层数据目录
    if [ -d ./execution/geth ] && [ "$(ls -A ./execution/geth 2>/dev/null || true)" ]; then
        dirty=true
    fi
    if compgen -G "./consensus/beacondata*" > /dev/null || compgen -G "./consensus/validatordata*" > /dev/null; then
        dirty=true
    fi
    # 3) 创世与信号文件
    if [ -f ./consensus/genesis.ssz ]; then
        dirty=true
    fi
    if [ -d ./share/signals ] && [ "$(ls -A ./share/signals 2>/dev/null || true)" ]; then
        dirty=true
    fi

    $dirty && return 0 || return 1
}

# 预检：若存在残留则自动清理
preflight_clean_if_needed() {
    log_step "步骤0: 环境预检..."
    if has_dirty_state; then
        log_warning "检测到上次运行的残留（容器/数据/信号），将自动执行清理..."
        clean_all
    else
        log_success "环境干净，无需清理"
    fi
}

# 等待服务就绪
wait_for_service_ready() {
    local service_endpoint=$1
    local max_wait=${2:-60}
    local service_type=${3:-"geth"}
    local wait_count=0
    
    log_info "等待服务就绪: $service_endpoint ($service_type)"
    
    while [ $wait_count -lt $max_wait ]; do
        if [ "$service_type" = "geth" ]; then
            # geth JSON-RPC 检测
            if echo '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | curl -sS -m 2 --connect-timeout 1 -X POST -H "Content-Type: application/json" -d @- "$service_endpoint" | grep -q "jsonrpc"; then
                log_success "服务已就绪: $service_endpoint"
                return 0
            fi
        elif [ "$service_type" = "beacon" ]; then
            # beacon-chain REST API 检测
            if curl -sS -m 2 --connect-timeout 1 "http://$service_endpoint/eth/v1/node/health" | grep -q "200\|OK" || curl -sS -m 2 --connect-timeout 1 "http://$service_endpoint/eth/v1/node/identity" | grep -q "enr"; then
                log_success "服务已就绪: $service_endpoint"
                return 0
            fi
        elif [ "$service_type" = "block-tree-visualizer" ]; then
            # 区块树可视化器健康检查
            if curl -sS -m 2 --connect-timeout 1 "http://$service_endpoint" | grep -q '"status":"healthy"'; then
                log_success "服务已就绪: $service_endpoint"
                return 0
            fi
        else
            # 简单的 TCP 连接检测
            if curl -sS -m 2 --connect-timeout 1 "$service_endpoint" >/dev/null 2>&1; then
                log_success "服务已就绪: $service_endpoint"
                return 0
            fi
        fi
        wait_count=$((wait_count + 1))
        sleep 2
    done
    
    log_error "服务就绪超时: $service_endpoint"
    return 1
}

# 创建信号文件
create_signal() {
    local signal_name=$1
    local signal_file="$SIGNAL_DIR/$signal_name"
    touch "$signal_file"
    log_debug "创建信号: $signal_name"
}

# 等待信号文件
wait_for_signal() {
    local signal_name=$1
    local signal_file="$SIGNAL_DIR/$signal_name"
    log_info "等待信号: $signal_name"
    while [ ! -f "$signal_file" ]; do
        sleep 0.5
    done
    log_success "收到信号: $signal_name"
}

# =============================================================================
# 网络管理函数
# =============================================================================

# 清理现有网络配置
cleanup_existing_network() {
    log_info "清理现有的网络配置..."
    
    # 清理beacon相关网络设备（智能检测）
    local beacon_bridges=$(ip link show 2>/dev/null | grep -o "br-beacon-[0-9]*" | head -20)
    local beacon_taps=$(ip link show 2>/dev/null | grep -o "tap-beacon-[0-9]*" | head -20)
    
    # 清理bridge设备
    for bridge_name in $beacon_bridges; do
        if ip link show $bridge_name >/dev/null 2>&1; then
            log_debug "清理bridge: $bridge_name"
            sudo ip link del $bridge_name 2>/dev/null || true
        fi
    done
    
    # 清理tap设备
    for tap_name in $beacon_taps; do
        if ip link show $tap_name >/dev/null 2>&1; then
            log_debug "清理tap: $tap_name"
            sudo ip link del $tap_name 2>/dev/null || true
        fi
    done
    
    # 清理veth设备
    local beacon_veths=$(ip link show 2>/dev/null | grep -o "veth-[0-9]*-in" | head -20)
    for veth_name in $beacon_veths; do
        local base_name=$(echo $veth_name | sed 's/-in$//')
        if ip link show $veth_name >/dev/null 2>&1; then
            log_debug "清理veth: $base_name"
            sudo ip link del $veth_name 2>/dev/null || true
        fi
    done
    
    # 清理iptables规则
    log_debug "清理iptables规则..."
    while true; do
        local rule_line=$(sudo iptables -L FORWARD -v -n --line-numbers 2>/dev/null | grep br-beacon | head -1 | awk '{print $1}')
        if [ -z "$rule_line" ]; then
            break
        fi
        log_debug "删除iptables规则 #$rule_line"
        sudo iptables -D FORWARD $rule_line 2>/dev/null || true
    done
    
    # 清理网络命名空间
    sudo rm -rf /var/run/netns 2>/dev/null || true
    sudo mkdir -p /var/run/netns
    
    log_success "网络清理完成"
}

# 创建 TAP 设备
create_tap_device() {
    local service=$1
    local node_id=$2
    local tap_name="tap-beacon-$node_id"
    
    log_debug "为 $service 创建 TAP 设备: $tap_name"
    sudo ip tuntap add "$tap_name" mode tap
    sudo ip link set "$tap_name" promisc on
    sudo ip link set "$tap_name" up
}

# 创建 bridge
create_bridge() {
    local service=$1
    local node_id=$2
    local bridge_name="br-beacon-$node_id"
    
    log_debug "为 $service 创建 bridge: $bridge_name"
    sudo ip link add name "$bridge_name" type bridge
    sudo ip link set dev "$bridge_name" up
}

# 配置 iptables 规则
configure_iptables() {
    local service=$1
    local node_id=$2
    local bridge_name="br-beacon-$node_id"
    
    log_debug "为 $service 配置 iptables 规则"
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -i "$bridge_name" -j ACCEPT
    sudo iptables -I FORWARD -m physdev --physdev-is-bridged -o "$bridge_name" -j ACCEPT
}

# 设置网络命名空间
setup_network_namespace() {
    local container_name=$1
    local pid=$(docker inspect --format '{{ .State.Pid }}' "$container_name")
    
    if [ -z "$pid" ] || [ "$pid" -eq 0 ]; then
        log_error "容器 $container_name 未运行或无法获取PID"
        return 1
    fi
    
    log_debug "设置网络命名空间: $container_name (PID: $pid)"
    
    if [ ! -L "/var/run/netns/$pid" ]; then
        sudo ln -sf "/proc/$pid/ns/net" "/var/run/netns/$pid"
    fi
}

# 配置容器网络
configure_container_network() {
    local service=$1
    local node_id=$2
    local ip_addr=$3
    local bridge_name="br-beacon-$node_id"
    local veth_name="veth-$node_id"
    local pid=$(docker inspect --format '{{ .State.Pid }}' "$service")
    local mac_addr="12:34:88:5D:61:$(printf "%02X" "$node_id")"
    
    log_info "配置容器网络: $service (PID: $pid) -> $ip_addr"
    
    # 创建 veth pair
    sudo ip link add "${veth_name}-in" type veth peer name "${veth_name}-ex"
    
    # 配置 bridge 端
    sudo ip link set "${veth_name}-in" master "$bridge_name"
    sudo ip link set "${veth_name}-in" up
    
    # 配置容器端
    log_debug "移动 veth-ex 到容器网络命名空间..."
    sudo ip link set "${veth_name}-ex" netns "$pid"
    
    # 清理可能存在的旧 eth1 接口
    log_debug "清理容器内可能存在的 eth1 接口..."
    sudo ip netns exec "$pid" ip link del eth1 2>/dev/null || true
    
    # 重命名 veth 设备为 eth1 (保留 eth0 为 Docker 默认网络)
    log_debug "重命名 ${veth_name}-ex 为 eth1..."
    sudo ip netns exec "$pid" ip link set dev "${veth_name}-ex" name eth1
    
    # 设置 MAC 地址
    log_debug "设置 MAC 地址..."
    sudo ip netns exec "$pid" ip link set eth1 address "$mac_addr"
    
    # 启动 eth1 接口
    log_debug "启动 eth1 接口..."
    sudo ip netns exec "$pid" ip link set eth1 up
    
    # 分配IP地址
    log_debug "分配IP地址 ${ip_addr}/16..."
    sudo ip netns exec "$pid" ip addr add "${ip_addr}/16" dev eth1
    
    log_success "容器网络配置完成: $service -> $ip_addr"
    
    # 测试网络连通性
    log_debug "测试网络连通性..."
    sudo ip netns exec "$pid" ping -c 1 -W 2 127.0.0.1 >/dev/null 2>&1 && log_debug "✓ 本地回环可达" || log_warning "✗ 本地回环不可达"
    sudo ip netns exec "$pid" ping -c 1 -W 2 ${ip_addr} >/dev/null 2>&1 && log_debug "✓ NS-3 IP 可达" || log_warning "✗ NS-3 IP 不可达"
}

# 连接 TAP 设备到 bridge
connect_tap_to_bridge() {
    local service=$1
    local node_id=$2
    local tap_name="tap-beacon-$node_id"
    local bridge_name="br-beacon-$node_id"
    
    log_debug "连接 TAP 设备到 bridge: $tap_name -> $bridge_name"
    sudo ip link set "$tap_name" master "$bridge_name"
    sudo ip link set "$tap_name" up
}

# 设置容器网络命名空间
setup_container_network_namespace() {
    log_info "配置容器网络命名空间..."
    
    # 为每个容器创建网络设备
    for i in "${!CONTAINER_NAMES[@]}"; do
        local service="${CONTAINER_NAMES[$i]}"
        local ip="${CONTAINER_IPS[$i]}"
        local node_id=$((i + 1))
        
        log_info "配置 $service 的网络环境 -> $ip"
        
        # 创建 TAP 设备
        create_tap_device "$service" "$node_id"
        
        # 创建 bridge
        create_bridge "$service" "$node_id"
        
        # 配置 iptables
        configure_iptables "$service" "$node_id"
        
        # 设置网络命名空间
        setup_network_namespace "$service"
        
        # 配置容器网络
        configure_container_network "$service" "$node_id" "$ip"
        
        # 连接 TAP 到 bridge
        connect_tap_to_bridge "$service" "$node_id"
    done
    
    log_success "容器网络命名空间配置完成"
}

# =============================================================================
# 主要功能函数
# =============================================================================

# 构建容器
build_containers() {
    log_step "步骤1: 启动基础服务..."
    
    # 清理信号文件
    rm -rf "$SIGNAL_DIR"/*
    mkdir -p "$SIGNAL_DIR"
    
    # 启动基础服务：geth + 监控
    log_info "启动 geth、prometheus、grafana、区块树可视化器..."
    docker compose up -d geth prometheus grafana
    
    log_success "基础服务启动完成"
}

# 设置网络
setup_network() {
    log_step "步骤2: 设置网络..."
    
    # 设置集成模式环境变量
    export NS3_INTEGRATION=true
    
    # 启动 beacon-chain 容器（但服务暂停等待信号）
    log_info "启动 beacon-chain 容器（暂停状态）..."
    docker compose up -d --no-deps "${CONTAINER_NAMES[@]}"
    
    # 等待容器就绪
    log_info "等待 beacon-chain 容器启动完成..."
    sleep 3
    
    # 验证容器都在运行
    for service in "${CONTAINER_NAMES[@]}"; do
        if ! docker inspect --format '{{.State.Running}}' "$service" 2>/dev/null | grep -q "true"; then
            log_error "容器 $service 未正常运行"
            return 1
        fi
    done
    
    log_success "所有 beacon-chain 容器已启动"
    
    # 设置容器网络命名空间
    setup_container_network_namespace
    
    # 创建容器就绪信号
    create_signal "containers_ready.lock"
    
    log_success "网络设置完成"
}

# 运行 NS-3 网络模拟器
run_ns3_simulator() {
    log_step "步骤3: 运行 NS-3 网络模拟器..."
    
    # 检查 NS-3 目录
    if [ ! -d "$NS3_DIR" ]; then
        log_error "NS-3 目录不存在: $NS3_DIR"
        return 1
    fi
    
    # 复制 NS-3 场景文件
    log_info "准备 NS-3 场景文件..."
    if [ ! -f "ns3/src/multi-node-tap-scenario.cc" ]; then
        log_error "NS-3 场景文件不存在: ns3/src/multi-node-tap-scenario.cc"
        return 1
    fi
    
    cp ns3/src/multi-node-tap-scenario.cc "$NS3_DIR/scratch/"
    
    cd ns3
    ./run-ns3-simulation.sh 4 3600 "100Mbps" "1ms" > ../logs/ns3.log 2>&1 &
    NS3_PID=$!
    cd ..
    
    log_info "NS-3 模拟器 PID: $NS3_PID"
    
    # 等待 NS-3 网络初始化完成
    log_info "等待 NS-3 网络初始化..."
    sleep 5
    
    # 创建 NS-3 网络就绪信号
    create_signal "ns3_network_ready.lock"
    
    log_success "NS-3 网络模拟器启动完成"
}

# 运行以太坊测试网
run_ethereum_testnet() {
    log_step "步骤4: 分步启动以太坊测试网..."
    
    # 4.1 启动 beacon-chain-1 服务（网络已就绪，直接启动）
    log_info "4.1 启动 beacon-chain-1 服务..."
    create_signal "beacon1_ready.lock"
    
    # 等待 beacon-chain-1 服务启动并就绪
    log_info "等待 beacon-chain-1 服务就绪..."
    wait_for_service_ready "localhost:7777" 60 "beacon"
    
    # 4.2 收集 bootstrap 信息
    log_info "4.2 收集 bootstrap 信息..."
    docker compose up -d --no-deps bootstrap-collector
    docker compose wait bootstrap-collector
    
    # 验证 bootstrap 信息是否收集成功
    if [ ! -f "share/bootstrap_enr.txt" ] || [ ! -s "share/bootstrap_enr.txt" ]; then
        log_error "Bootstrap 信息收集失败"
        return 1
    fi
    
    log_info "Bootstrap ENR: $(cat share/bootstrap_enr.txt)"
    create_signal "bootstrap_ready.lock"
    
    # 4.3 启动其他 beacon-chain 服务
    log_info "4.3 启动其他 beacon-chain 服务..."
    create_signal "network_ready.lock"
    
    # 4.4 启动 validator 服务
    log_info "4.4 启动 validator 服务..."
    docker compose up -d --no-deps validator-1 validator-2 validator-3 validator-4
    
    log_success "以太坊测试网启动完成！"
}

# 检查区块树可视化器状态
check_block_tree_visualizer_status() {
    log_info "检查区块树可视化器状态..."
    
    # 检查容器是否运行
    if docker inspect --format '{{.State.Running}}' "block-tree-visualizer" 2>/dev/null | grep -q "true"; then
        log_success "区块树可视化器容器正在运行"
        
        # 检查健康状态
        if curl -s "http://localhost:8888/health" | grep -q '"status":"healthy"'; then
            local health_info=$(curl -s "http://localhost:8888/health" | grep -o '"active_connections":[0-9]*' | cut -d':' -f2)
            log_success "区块树可视化器服务健康，活跃连接: ${health_info:-0}"
            
            # 检查数据源
            local data_sources=$(curl -s "http://localhost:8888/health" | grep -o '"data_sources":[0-9]*' | cut -d':' -f2)
            if [ "${data_sources:-0}" -gt 0 ]; then
                log_success "已连接到 ${data_sources} 个beacon节点数据源"
            else
                log_warning "尚未连接到beacon节点数据源，请稍等片刻"
            fi
            
            echo -e "\n${GREEN}🌐 区块树可视化界面: ${CYAN}http://localhost:8888${NC}"
            echo -e "${GREEN}📊 Grafana仪表板: ${CYAN}http://localhost:3000${NC} (admin/admin)"
            echo -e "${GREEN}📡 API接口: ${CYAN}http://localhost:8888/api/fork-choice${NC}"
        else
            log_warning "区块树可视化器服务未就绪，请稍后再试"
        fi
    else
        log_error "区块树可视化器容器未运行"
    fi
}

# 显示网络状态
show_network_status() {
    log_info "=== 网络状态摘要 ==="
    
    echo -e "\n${YELLOW}=== Docker 容器状态 ===${NC}"
    docker compose ps
    
    echo -e "\n${YELLOW}=== 网络设备状态 ===${NC}"
    sudo ip link show | grep -E "(br-beacon|tap-beacon|veth-)" || echo "未找到网络设备"
    
    echo -e "\n${YELLOW}=== beacon-chain 节点 IP 地址 ===${NC}"
    for i in "${!CONTAINER_NAMES[@]}"; do
        echo "  ${CONTAINER_NAMES[$i]} -> ${CONTAINER_IPS[$i]}"
    done
    
    echo -e "\n${YELLOW}=== 重要端口 ===${NC}"
    echo "  Geth RPC: localhost:8545"
    echo "  Beacon-1 API: localhost:7777"
    echo "  Beacon-2 API: localhost:7778"
    echo "  Beacon-3 API: localhost:7779"
    echo "  Beacon-4 API: localhost:7780"
    echo "  Prometheus: localhost:9090"
    echo "  Grafana:    localhost:3000"
    echo "  区块树可视化: localhost:8888"
    echo "  Metrics:    geth:6060, beacon:8081..8084, validator:8181..8184"
    echo "  pprof:      geth:6061"
    
    echo -e "\n${YELLOW}=== 信号文件状态 ===${NC}"
    ls -la "$SIGNAL_DIR" 2>/dev/null || echo "无信号文件"
}

# 综合清理函数
clean_all() {
    log_info "开始清理所有环境..."
    
    # 1. 停止所有容器
    log_info "停止Docker容器..."
    docker compose down 2>/dev/null || true
    
    # 停止独立运行的区块树可视化器（如果存在）
    docker stop eth-block-tree-visualizer 2>/dev/null || true
    docker rm eth-block-tree-visualizer 2>/dev/null || true
    
    # 2. 清理网络设备
    cleanup_existing_network
    
    # 3. 清理数据目录
    log_info "清理数据目录..."
    sudo rm -rf ./execution/geth 2>/dev/null || true
    sudo rm -rf ./consensus/beacondata* 2>/dev/null || true
    sudo rm -rf ./consensus/validatordata* 2>/dev/null || true
    sudo rm -rf ./consensus/genesis.ssz 2>/dev/null || true
    
    # 4. 清理信号文件
    log_info "清理信号文件..."
    rm -rf "$SIGNAL_DIR"/* 2>/dev/null || true
    rm -rf ./share/bootstrap_enr.txt 2>/dev/null || true
    
    # 5. 清理Docker资源
    log_info "清理Docker资源..."
    docker container prune -f 2>/dev/null || true
    docker image prune -f 2>/dev/null || true
    
    # 6. 终止可能的后台进程
    log_info "终止NS-3后台进程..."
    pkill -f "ns3.*multi-node-tap-scenario" 2>/dev/null || true
    pkill -f "run-ns3-simulation" 2>/dev/null || true
    
    log_success "环境清理完成！"
}

# 运行区块树可视化器
run_block_tree_visualizer() {
    log_step "步骤5: 启动区块树可视化器..."
    
    # 确保所有beacon节点都已启动并且可以访问
    log_info "验证beacon节点可用性..."
    local beacon_ready=0
    
    for port in 7777 7778 7779 7780; do
        if curl -s --connect-timeout 2 "http://localhost:$port/eth/v1/node/health" > /dev/null; then
            log_debug "✓ Beacon节点端口 $port 可访问"
            beacon_ready=$((beacon_ready + 1))
        else
            log_warning "⚠ Beacon节点端口 $port 暂时不可访问"
        fi
    done
    
    if [ $beacon_ready -eq 0 ]; then
        log_error "没有可访问的beacon节点，无法启动可视化器"
        return 1
    fi
    
    log_info "发现 $beacon_ready 个可访问的beacon节点，启动可视化器..."
    
    # 启动区块树可视化器
    log_info "启动区块树可视化器容器..."
    docker compose up -d --no-deps block-tree-visualizer
    
    # 等待可视化器就绪
    log_info "等待区块树可视化器就绪..."
    local wait_count=0
    local max_wait=60
    
    while [ $wait_count -lt $max_wait ]; do
        if curl -s "http://localhost:8888/health" | grep -q '"status": "healthy"'; then
            log_success "区块树可视化器启动成功！"
            break
        fi
        wait_count=$((wait_count + 1))
        sleep 2
    done
    
    if [ $wait_count -ge $max_wait ]; then
        log_warning "可视化器就绪检测超时，但容器可能仍在启动中"
    fi
    
    # 等待数据源连接
    log_info "等待数据源连接..."
    sleep 5
    
    # 检查可视化器状态
    check_block_tree_visualizer_status
    
    log_success "区块树可视化器启动完成！"
}
