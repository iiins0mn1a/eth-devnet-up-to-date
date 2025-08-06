#!/bin/bash

# 测试阶段一：基础服务启动

set -e

# 引入主脚本的函数
source ./main.sh

# 测试函数
test_phase1() {
    echo "======================================"
    echo "测试阶段一：基础服务启动"
    echo "======================================"
    
    # 清理环境
    echo ">>> 清理测试环境"
    docker compose down 2>/dev/null || true
    
    # 使用正确的清理脚本
    sudo ./clean.sh
    
    # 清理信号文件
    rm -rf share/signals/*
    mkdir -p share/signals
    
    # 测试步骤1：构建容器
    echo ""
    echo ">>> 测试：基础服务启动"
    
    # 一次性启动所有相关服务，避免重复运行
    echo "启动所有基础服务（包括 geth）..."
    docker compose up -d geth
    
    # 检查服务状态
    echo "检查所有服务状态..."
    docker compose ps
    
    # 等待 geth 容器启动
    sleep 10
    
    # 检查 geth 状态
    echo "检查 geth 状态..."
    docker compose ps geth
    
    # 检查 geth 日志
    echo "检查 geth 日志（最后10行）..."
    docker compose logs --tail=10 geth
    
    echo ""
    echo "✅ 阶段一测试完成！"
    echo "如果看到 geth 正在运行且没有错误，则基础服务启动成功。"
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
test_phase1