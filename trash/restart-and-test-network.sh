#!/bin/bash

echo "=== 重启网络并测试所有节点连接 ==="

# 1. 停止当前网络
echo "1. 停止当前网络..."
./main.sh clean

# 2. 重新启动（使用1ms延迟）
echo "2. 启动测试网（1ms网络延迟）..."
./main.sh &
MAIN_PID=$!

echo "测试网启动中，PID: $MAIN_PID"
echo "等待90秒让所有服务启动..."
sleep 90

# 3. 测试网络延迟
echo "3. 测试网络延迟..."
BC1_PID=$(docker inspect beacon-chain-1 --format '{{ .State.Pid }}' 2>/dev/null)
BC2_PID=$(docker inspect beacon-chain-2 --format '{{ .State.Pid }}' 2>/dev/null)

if [ -n "$BC1_PID" ] && [ -n "$BC2_PID" ]; then
    echo "测试延迟（beacon-1 -> beacon-2）:"
    sudo ip netns exec $BC1_PID ping -c 5 -i 0.2 10.0.0.2
    
    echo -e "\n测试延迟（beacon-2 -> beacon-1）:"
    sudo ip netns exec $BC2_PID ping -c 5 -i 0.2 10.0.0.1
fi

# 4. 检查所有beacon-chain的连接状态
echo -e "\n4. 检查所有beacon-chain的连接状态..."
sleep 30

echo "beacon-chain-1 (端口7777):"
curl -s "http://localhost:7777/eth/v1/node/peers" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "API not ready"

echo "beacon-chain-2 (端口7778):"
curl -s "http://localhost:7778/eth/v1/node/peers" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "API not ready"

echo "beacon-chain-3 (端口7779):"
curl -s "http://localhost:7779/eth/v1/node/peers" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "API not ready"

echo "beacon-chain-4 (端口7780):"
curl -s "http://localhost:7780/eth/v1/node/peers" 2>/dev/null | jq '.data | length' 2>/dev/null || echo "API not ready"

# 5. 检查活跃连接
echo -e "\n5. 检查活跃连接详情..."
echo "beacon-chain-1 活跃peers:"
curl -s "http://localhost:7777/eth/v1/node/peers" 2>/dev/null | jq '.data[] | select(.state == "connected") | {peer_id: .peer_id, direction: .direction}' 2>/dev/null || echo "No active peers"

echo "beacon-chain-2 活跃peers:"
curl -s "http://localhost:7778/eth/v1/node/peers" 2>/dev/null | jq '.data[] | select(.state == "connected") | {peer_id: .peer_id, direction: .direction}' 2>/dev/null || echo "No active peers"

echo "beacon-chain-3 活跃peers:"
curl -s "http://localhost:7779/eth/v1/node/peers" 2>/dev/null | jq '.data[] | select(.state == "connected") | {peer_id: .peer_id, direction: .direction}' 2>/dev/null || echo "No active peers"

echo "beacon-chain-4 活跃peers:"
curl -s "http://localhost:7780/eth/v1/node/peers" 2>/dev/null | jq '.data[] | select(.state == "connected") | {peer_id: .peer_id, direction: .direction}' 2>/dev/null || echo "No active peers"

# 6. 检查网络拓扑
echo -e "\n6. 检查网络拓扑..."
echo "Docker容器状态:"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo -e "\n网络设备状态:"
ip link show | grep -E "(br-beacon|tap-beacon)" | head -10

echo -e "\n=== 测试完成 ===" 