#!/bin/bash

# dir for host
# WORKDIR=/home/ins0/Learning/Testnet/NewTry/eth-pos-devnet

# wait 10s
sleep 10

enr=$(curl -s beacon-chain-1:7777/eth/v1/node/identity | jq -r '.data.enr')
        
if [ "$enr" != "null" ] && [ "$enr" != "" ]; then
    echo "成功获取ENR: $enr"
    echo "$enr" > /share/bootstrap_enr.txt
    echo "ENR已保存到 .../share/bootstrap_enr.txt"
else
    echo "ENR为空或null，Fail"
    exit 1
fi

echo "ENR收集完成，其他节点可以开始启动"
