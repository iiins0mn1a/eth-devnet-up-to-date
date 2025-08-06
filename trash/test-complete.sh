#!/bin/bash

# 完整流程测试脚本

set -e

# 引入 main.sh 中的函数
source ./main.sh

echo "=== 完整流程测试 ==="

# 1. 清理环境
echo "1. 清理环境..."
clean_all

# 2. 运行完整流程
echo "2. 运行完整流程..."
echo "开始执行以太坊PoS开发网络设置..."

# 步骤1: 使用docker-compose.yml构建容器
build_containers

# 步骤2: 设置网络
setup_network

# 步骤3: 运行ns-3网络模拟器
run_ns3_simulator

# 步骤4: 运行相关客户端和以太坊测试网
run_ethereum_testnet

echo "所有步骤执行完成！"