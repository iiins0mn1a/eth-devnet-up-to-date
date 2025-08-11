#!/bin/bash

# 启动区块树可视化服务的脚本
# 用于独立启动可视化服务或进行测试

set -e

echo "🚀 启动以太坊测试网区块树可视化服务..."

# 检查Docker是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker未运行或无法访问"
    exit 1
fi

# 设置项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VISUALIZER_DIR="$PROJECT_ROOT/block-tree-visualizer"

cd "$PROJECT_ROOT"

echo "📁 项目目录: $PROJECT_ROOT"
echo "🔧 构建区块树可视化服务..."

# 构建Docker镜像
docker build -t eth-block-tree-visualizer "$VISUALIZER_DIR"

echo "✅ 镜像构建完成"

# 检查beacon节点是否运行
echo "🔍 检查beacon节点状态..."
BEACON_RUNNING=false

for port in 7777 7778 7779 7780; do
    if curl -s "http://localhost:$port/eth/v1/node/health" > /dev/null 2>&1; then
        echo "✅ Beacon节点端口 $port 正常运行"
        BEACON_RUNNING=true
    else
        echo "⚠️  Beacon节点端口 $port 未响应"
    fi
done

if [ "$BEACON_RUNNING" = false ]; then
    echo "❌ 没有发现运行中的beacon节点"
    echo "💡 请先启动beacon节点：docker-compose up -d"
    exit 1
fi

# 启动可视化服务
echo "🎯 启动区块树可视化服务..."

docker run -d \
    --name eth-block-tree-visualizer \
    --network eth-pos-devnet_default \
    -p 8888:8000 \
    -e BEACON_ENDPOINTS="http://beacon-chain-1:7777,http://beacon-chain-2:7777,http://beacon-chain-3:7777,http://beacon-chain-4:7777" \
    --restart unless-stopped \
    eth-block-tree-visualizer

echo "⏳ 等待服务启动..."
sleep 5

# 健康检查
if curl -s "http://localhost:8888/health" > /dev/null; then
    echo "✅ 区块树可视化服务启动成功！"
    echo ""
    echo "🌐 Web界面: http://localhost:8888"
    echo "🔧 健康检查: http://localhost:8888/health"
    echo "📡 API接口: http://localhost:8888/api/fork-choice"
    echo ""
    echo "📊 Grafana仪表板: http://localhost:3000"
    echo "   用户名: admin"
    echo "   密码: admin"
    echo ""
    echo "📋 查看日志: docker logs -f eth-block-tree-visualizer"
else
    echo "❌ 服务启动失败，请检查日志："
    echo "docker logs eth-block-tree-visualizer"
    exit 1
fi
