#!/bin/bash

# 测试阶段二：网络配置和 NS-3 集成

set -e

# 引入主脚本的函数
source ./main.sh

# 测试函数
test_phase2() {
    echo "======================================"
    echo "测试阶段二：网络配置和容器启动"
    echo "======================================"
    
    # 清理环境
    echo ">>> 清理测试环境"
    docker compose down 2>/dev/null || true
    sudo ./clean.sh 2>/dev/null || true
    
    # 清理信号文件
    rm -rf share/signals/*
    mkdir -p share/signals
    
    echo ""
    echo ">>> 测试：阶段一 - 基础服务启动"
    
    # 先完成阶段一
    build_containers
    
    echo ""
    echo ">>> 测试：阶段二 - 网络配置"
    
    # 测试网络配置（不包含实际的 NS-3 部分）
    log_info "设置集成模式环境变量..."
    export NS3_INTEGRATION=true
    
    # 启动 beacon-chain 容器（但服务暂停等待信号）
    log_info "启动 beacon-chain 容器（暂停状态）..."
    # 使用 --no-deps 避免重新运行已完成的依赖服务
    docker compose up -d --no-deps beacon-chain-1 beacon-chain-2 beacon-chain-3 beacon-chain-4
    
    # 等待容器就绪
    log_info "等待 beacon-chain 容器启动完成..."
    sleep 10
    
    # 验证容器都在运行
    local services=("beacon-chain-1" "beacon-chain-2" "beacon-chain-3" "beacon-chain-4")
    for service in "${services[@]}"; do
        if ! docker inspect --format '{{.State.Running}}' "$service" 2>/dev/null | grep -q "true"; then
            log_error "容器 $service 未正常运行"
            return 1
        fi
    done
    
    log_success "所有 beacon-chain 容器已启动"
    
    # 检查容器状态
    echo "检查容器状态..."
    docker compose ps
    
    # 检查容器日志（应该显示等待信号）
    echo ""
    echo "检查 beacon-chain-1 日志（应该显示等待信号）..."
    docker compose logs --tail=5 beacon-chain-1
    
    echo ""
    echo "检查 beacon-chain-2 日志（应该显示等待信号）..."
    docker compose logs --tail=5 beacon-chain-2
    
    # 测试信号机制
    echo ""
    echo ">>> 测试：信号机制"
    
    # 创建测试信号
    create_signal "test_signal.lock"
    
    # 验证信号文件存在
    if [ -f "share/signals/test_signal.lock" ]; then
        log_success "信号机制工作正常"
    else
        log_error "信号机制失败"
        return 1
    fi
    
    echo ""
    echo "✅ 阶段二测试完成！"
    echo "- 基础服务启动成功"
    echo "- beacon-chain 容器启动成功（等待信号状态）"
    echo "- 信号机制工作正常"
}

# 清理函数
cleanup() {
    echo ""
    echo "清理测试环境..."
    docker compose down
}

# 信号处理
trap cleanup EXIT INT TERM

# 运行测试
test_phase2