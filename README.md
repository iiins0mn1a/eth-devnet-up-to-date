# Ethereum PoS Devnet

这是一个简化的以太坊权益证明（PoS）开发网络配置，包含4组共识客户端共享一个执行层客户端。

## 架构

- **执行层**: 1个geth客户端
- **共识层**: 4个beacon-chain节点
- **验证者**: 4个validator客户端，分配64个验证者
  - validator-1: 32个验证者 (索引0-31)
  - validator-2: 16个验证者 (索引32-47)
  - validator-3: 8个验证者 (索引48-55)
  - validator-4: 8个验证者 (索引56-63)

## 快速开始

### 启动网络
```bash
./start.sh
```

### 停止网络
```bash
./stop.sh
```

### 清理服务
```bash
# 清理所有服务并删除数据
./clean.sh
```

### 查看日志
```bash
# 查看所有服务日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f geth-execution
docker compose logs -f beacon-1
docker compose logs -f validator-1
```

## 配置说明

### 脚本化配置
所有服务的启动参数都定义在 `scripts/start-services.sh` 中，包括：

- `GETH_ARGS`: geth执行层客户端参数
- `BEACON_CHAIN_1_ARGS` 到 `BEACON_CHAIN_4_ARGS`: 4个beacon-chain节点参数
- `VALIDATOR_1_ARGS` 到 `VALIDATOR_4_ARGS`: 4个validator客户端参数

### 环境变量
可以通过环境变量自定义配置：

```bash
export CHAIN_ID=32382
export TOTAL_VALIDATORS=64
./start.sh
```

### 网络通信
- 所有beacon-chain节点通过P2P协议互相通信
- validator客户端连接到对应的beacon-chain节点
- 所有共识客户端共享同一个geth执行层客户端

## 文件结构

```
.
├── docker-compose.yml          # 简化的Docker Compose配置
├── scripts/
│   └── start-services.sh      # 服务启动参数定义
├── config/
│   ├── config.yml             # 基础配置
│   ├── config-1.yml           # beacon-chain-1配置
│   ├── config-2.yml           # beacon-chain-2配置
│   ├── config-3.yml           # beacon-chain-3配置
│   └── config-4.yml           # beacon-chain-4配置
├── start.sh                   # 启动脚本
├── stop.sh                    # 停止脚本
├── clean.sh                   # 清理脚本
└── README.md                  # 说明文档
```

## 容器命名

每个服务都有精简的容器名称，便于管理和调试：

- **执行层**: `geth-execution`, `geth-genesis`, `geth-db-cleaner`
- **共识层**: `beacon-1`, `beacon-2`, `beacon-3`, `beacon-4`
- **验证者**: `validator-1`, `validator-2`, `validator-3`, `validator-4`
- **创世**: `genesis-creator`

## 优势

1. **配置分离**: 复杂的启动参数从docker-compose.yml中分离到脚本中
2. **易于维护**: 修改参数只需要编辑脚本文件
3. **环境变量支持**: 可以通过环境变量自定义配置
4. **简化操作**: 使用简单的脚本启动和停止服务
5. **网络隔离**: 所有通信都在Docker内部网络中进行，提高安全性

## 故障排除

### 端口冲突
如果遇到端口冲突，检查是否有其他服务占用了相关端口。

### 权限问题
确保脚本有执行权限：
```bash
chmod +x start.sh stop.sh scripts/start-services.sh
```

### 数据清理
如果需要重新开始，可以清理数据：
```bash
./clean.sh
```
# WOrkflow

1. build containers with docker-compose.yml
2. setup the internet
3. run the ns-3 network simulator
4. run the related client and run the ethereum testnet;