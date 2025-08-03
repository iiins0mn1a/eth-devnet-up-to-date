#!/bin/bash

# 设置环境变量
export CHAIN_ID=${CHAIN_ID:-32382}
export TOTAL_VALIDATORS=64

# Geth 配置
export GETH_ARGS="
--http
--http.api=eth,net,web3 
--http.addr=0.0.0.0
--http.corsdomain=*
--ws
--ws.api=eth,net,web3
--ws.addr=0.0.0.0
--ws.origins=*
--authrpc.vhosts=*
--authrpc.addr=0.0.0.0
--authrpc.jwtsecret=/execution/jwtsecret
--datadir=/execution
--allow-insecure-unlock
--unlock=0x123463a4b065722e99115d6c222f267d9cabb524
--password=/execution/geth_password.txt
--nodiscover
--syncmode=full
"

# Beacon chain 1 配置
export BEACON_CHAIN_1_ARGS="
--datadir=/consensus/beacondata1
--min-sync-peers=0
--genesis-state=/consensus/genesis.ssz
--bootstrap-node=
--interop-eth1data-votes
--chain-config-file=/config/config-1.yml
--contract-deployment-block=0
--chain-id=${CHAIN_ID}
--rpc-host=0.0.0.0
--grpc-gateway-host=0.0.0.0
--execution-endpoint=http://geth:8551
--accept-terms-of-use
--jwt-secret=/execution/jwtsecret
--suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524
--minimum-peers-per-subnet=0
--enable-debug-rpc-endpoints
--force-clear-db
--p2p-static-id=true
--p2p-max-peers=70
--peer=beacon-chain-2:13000
--peer=beacon-chain-3:13000
--peer=beacon-chain-4:13000
"

# Beacon chain 2 配置
export BEACON_CHAIN_2_ARGS="
--datadir=/consensus/beacondata2
--min-sync-peers=0
--genesis-state=/consensus/genesis.ssz
--bootstrap-node=
--interop-eth1data-votes
--chain-config-file=/config/config-2.yml
--contract-deployment-block=0
--chain-id=${CHAIN_ID}
--rpc-host=0.0.0.0
--grpc-gateway-host=0.0.0.0
--execution-endpoint=http://geth:8551
--accept-terms-of-use
--jwt-secret=/execution/jwtsecret
--suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524
--minimum-peers-per-subnet=0
--enable-debug-rpc-endpoints
--force-clear-db
--p2p-static-id=true
--p2p-max-peers=70
--peer=beacon-chain-1:13000
--peer=beacon-chain-3:13000
--peer=beacon-chain-4:13000
"

# Beacon chain 3 配置
export BEACON_CHAIN_3_ARGS="
--datadir=/consensus/beacondata3
--min-sync-peers=0
--genesis-state=/consensus/genesis.ssz
--bootstrap-node=
--interop-eth1data-votes
--chain-config-file=/config/config-3.yml
--contract-deployment-block=0
--chain-id=${CHAIN_ID}
--rpc-host=0.0.0.0
--grpc-gateway-host=0.0.0.0
--execution-endpoint=http://geth:8551
--accept-terms-of-use
--jwt-secret=/execution/jwtsecret
--suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524
--minimum-peers-per-subnet=0
--enable-debug-rpc-endpoints
--force-clear-db
--p2p-static-id=true
--p2p-max-peers=70
--peer=beacon-chain-1:13000
--peer=beacon-chain-2:13000
--peer=beacon-chain-4:13000
"

# Beacon chain 4 配置
export BEACON_CHAIN_4_ARGS="
--datadir=/consensus/beacondata4
--min-sync-peers=0
--genesis-state=/consensus/genesis.ssz
--bootstrap-node=
--interop-eth1data-votes
--chain-config-file=/config/config-4.yml
--contract-deployment-block=0
--chain-id=${CHAIN_ID}
--rpc-host=0.0.0.0
--grpc-gateway-host=0.0.0.0
--execution-endpoint=http://geth:8551
--accept-terms-of-use
--jwt-secret=/execution/jwtsecret
--suggested-fee-recipient=0x123463a4b065722e99115d6c222f267d9cabb524
--minimum-peers-per-subnet=0
--enable-debug-rpc-endpoints
--force-clear-db
--p2p-static-id=true
--p2p-max-peers=70
--peer=beacon-chain-1:13000
--peer=beacon-chain-2:13000
--peer=beacon-chain-3:13000
"



# Validator 配置
export VALIDATOR_1_ARGS="
--beacon-rpc-provider=beacon-chain-1:4000
--datadir=/consensus/validatordata1
--accept-terms-of-use
--interop-num-validators=32
--interop-start-index=0
--chain-config-file=/config/config-1.yml
--force-clear-db
"

export VALIDATOR_2_ARGS="
--beacon-rpc-provider=beacon-chain-2:4000
--datadir=/consensus/validatordata2
--accept-terms-of-use
--interop-num-validators=16
--interop-start-index=32
--chain-config-file=/config/config-2.yml
--force-clear-db
"

export VALIDATOR_3_ARGS="
--beacon-rpc-provider=beacon-chain-3:4000
--datadir=/consensus/validatordata3
--accept-terms-of-use
--interop-num-validators=8
--interop-start-index=48
--chain-config-file=/config/config-3.yml
--force-clear-db
"

export VALIDATOR_4_ARGS="
--beacon-rpc-provider=beacon-chain-4:4000
--datadir=/consensus/validatordata4
--accept-terms-of-use
--interop-num-validators=8
--interop-start-index=56
--chain-config-file=/config/config-4.yml
--force-clear-db
"

echo "Arguments ready!"