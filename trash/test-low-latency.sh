#!/bin/bash

echo "=== 测试低延迟网络配置 ==="

# 1. 清理现有环境
echo "1. 清理环境..."
./main.sh clean

# 2. 重新启动（使用20ms延迟）
echo "2. 启动测试网（20ms网络延迟）..."
./main.sh &
MAIN_PID=$!

echo "测试网启动中，PID: $MAIN_PID"
echo "等待60秒让网络稳定..."
sleep 60

# 3. 测试新的网络延迟
echo "3. 测试网络延迟..."
BC1_PID=$(docker inspect beacon-chain-1 --format '{{ .State.Pid }}' 2>/dev/null)
BC2_PID=$(docker inspect beacon-chain-2 --format '{{ .State.Pid }}' 2>/dev/null)

if [ -n "$BC1_PID" ] && [ -n "$BC2_PID" ]; then
    echo "测试延迟（beacon-1 -> beacon-2）:"
    sudo ip netns exec $BC1_PID ping -c 3 10.0.0.2
    
    echo -e "\n测试延迟（beacon-2 -> beacon-1）:"
    sudo ip netns exec $BC2_PID ping -c 3 10.0.0.1
    
    echo -e "\n4. 检查P2P连接状态..."
    sleep 30  # 再等待30秒让P2P连接稳定
    
    echo "beacon-chain-1 peer连接数:"
    curl -s "http://localhost:7777/eth/v1/node/peers" | jq '.data | length'
    
    echo "beacon-chain-2 peer连接数:"
    curl -s "http://localhost:7778/eth/v1/node/peers" | jq '.data | length'
    
    echo -e "\n5. 检查连接状态详情..."
    echo "beacon-chain-1 active peers:"
    curl -s "http://localhost:7777/eth/v1/node/peers" | jq '.data[] | select(.state == "connected") | {peer_id: .peer_id, direction: .direction}'
    
    echo "beacon-chain-2 active peers:"  
    curl -s "http://localhost:7778/eth/v1/node/peers" | jq '.data[] | select(.state == "connected") | {peer_id: .peer_id, direction: .direction}'
    
else
    echo "容器未运行，检查启动状态"
fi

echo -e "\n=== 测试完成 ==="