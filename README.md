# 以太坊PoS测试网 - NS-3网络集成版

## 📋 项目概述

这是一个基于NS-3网络模拟器的以太坊PoS测试网，支持在模拟网络环境中运行真实的以太坊节点，用于研究和测试网络协议、延迟影响等场景。

## 🏗️ 系统架构

### 网络拓扑
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Beacon-1      │    │   Beacon-2      │    │   Beacon-3      │
│   (Bootstrap)   │    │                 │    │                 │
│   10.0.0.1      │    │   10.0.0.2      │    │   10.0.0.3      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────────┐
                    │   Beacon-4      │
                    │                 │
                    │   10.0.0.4      │
                    └─────────────────┘
                                 │
                    ┌─────────────────┐
                    │   NS-3 Network  │
                    │   (CSMA LAN)    │
                    │   Delay: 1ms    │
                    └─────────────────┘
```

### 组件说明
- **执行层**: Go-Ethereum (geth) - 处理交易和状态
- **共识层**: Prysm Beacon Chain - 处理区块共识
- **验证者**: Prysm Validator - 参与共识验证
- **网络模拟**: NS-3 - 提供可控的网络环境

## 🚀 快速开始

### 前置要求
- Docker & Docker Compose
- NS-3.45 安装在 `/home/ins0/Learning/Testnet/NS-3-Sim/ns-3.45`
- Linux 系统 (支持网络命名空间)

### 启动测试网
```bash
# 启动完整测试网
./main.sh

# 查看状态
./main.sh status

# 清理环境
./main.sh clean

# 查看帮助
./main.sh help
```

### 端口映射
| 服务 | 端口 | 说明 |
|------|------|------|
| Geth RPC | 8545 | JSON-RPC接口 |
| Geth WebSocket | 8546 | WebSocket接口 |
| Beacon-1 API | 7777 | Beacon Chain API |
| Beacon-2 API | 7778 | Beacon Chain API |
| Beacon-3 API | 7779 | Beacon Chain API |
| Beacon-4 API | 7780 | Beacon Chain API |

## 📁 项目结构

```
eth-pos-devnet/
├── main.sh                          # 主启动脚本
├── docker-compose.yml               # Docker服务配置
├── README.md                        # 项目说明文档
├── restart-and-test-network.sh      # 网络测试脚本
├── config/                          # 配置文件
│   ├── config-1.yml                # Beacon-1配置
│   ├── config-2.yml                # Beacon-2配置
│   ├── config-3.yml                # Beacon-3配置
│   └── config-4.yml                # Beacon-4配置
├── scripts/                         # 启动脚本
│   ├── beacon-chain-1-entrypoint.sh # Beacon-1启动脚本
│   ├── beacon-chain-2-entrypoint.sh # Beacon-2启动脚本
│   ├── beacon-chain-3-entrypoint.sh # Beacon-3启动脚本
│   ├── beacon-chain-4-entrypoint.sh # Beacon-4启动脚本
│   ├── beacon-chain-template.sh     # 脚本模板
│   ├── validator-1-entrypoint.sh   # Validator-1启动脚本
│   ├── validator-2-entrypoint.sh   # Validator-2启动脚本
│   ├── validator-3-entrypoint.sh   # Validator-3启动脚本
│   ├── validator-4-entrypoint.sh   # Validator-4启动脚本
│   └── geth-entrypoint.sh          # Geth启动脚本
├── ns3/                            # NS-3网络配置
│   └── src/
│       └── multi-node-tap-scenario.cc # NS-3场景文件
├── logs/                           # 日志文件
│   ├── beacon-1.log               # Beacon-1日志
│   ├── beacon-2.log               # Beacon-2日志
│   ├── beacon-3.log               # Beacon-3日志
│   ├── beacon-4.log               # Beacon-4日志
│   └── ns3.log                    # NS-3模拟器日志
├── share/                          # 共享文件
│   ├── signals/                   # 信号文件目录
│   └── bootstrap_enr.txt          # Bootstrap节点信息
├── consensus/                      # 共识层数据
│   ├── beacondata1/              # Beacon-1数据
│   ├── beacondata2/              # Beacon-2数据
│   ├── beacondata3/              # Beacon-3数据
│   ├── beacondata4/              # Beacon-4数据
│   ├── validatordata1/           # Validator-1数据
│   ├── validatordata2/           # Validator-2数据
│   ├── validatordata3/           # Validator-3数据
│   ├── validatordata4/           # Validator-4数据
│   └── genesis.ssz               # 创世状态文件
└── execution/                     # 执行层数据
    ├── geth/                     # Geth数据目录
    ├── genesis.json              # Geth创世文件
    └── jwtsecret                 # JWT密钥文件
```

## 🔧 代码优化说明

### 1. main.sh 优化
- ✅ **模块化结构**: 按功能分组函数
- ✅ **严格错误处理**: 使用 `set -euo pipefail`
- ✅ **详细注释**: 每个函数都有说明
- ✅ **配置常量**: 使用 `readonly` 定义常量
- ✅ **彩色日志**: 不同级别的日志使用不同颜色
- ✅ **依赖检查**: 启动前检查必要命令和目录
- ✅ **超时处理**: 信号等待添加超时机制

### 2. docker-compose.yml 优化
- ✅ **分组注释**: 按服务类型分组
- ✅ **详细说明**: 每个服务都有功能说明
- ✅ **端口注释**: 端口映射添加说明
- ✅ **依赖关系**: 清晰的依赖关系配置
- ✅ **环境变量**: 统一的环境变量配置

### 3. scripts/ 优化
- ✅ **统一模板**: 创建通用脚本模板
- ✅ **错误处理**: 添加文件检查和错误处理
- ✅ **超时机制**: 信号等待添加超时
- ✅ **详细日志**: 时间戳和日志级别
- ✅ **配置常量**: 使用常量定义路径

## 🧪 测试功能

### 网络测试
```bash
# 测试网络延迟和连接
./restart-and-test-network.sh
```

### API测试
```bash
# 检查beacon-chain连接状态
curl http://localhost:7777/eth/v1/node/peers | jq

# 检查所有节点状态
for port in 7777 7778 7779 7780; do
    echo "Port $port:"
    curl -s "http://localhost:$port/eth/v1/node/peers" | jq '.data | length'
done
```

## 🔍 故障排除

### 常见问题

1. **P2P连接失败**
   - 检查NS-3网络是否正常运行
   - 验证网络延迟设置 (当前: 1ms)
   - 查看beacon-chain日志

2. **容器启动失败**
   - 检查Docker服务状态
   - 验证端口是否被占用
   - 查看容器日志

3. **网络设备问题**
   - 清理现有网络配置: `./main.sh clean`
   - 检查TAP设备状态: `ip link show | grep tap-beacon`
   - 重启网络服务

### 日志位置
- **Beacon Chain**: `logs/beacon-*.log`
- **NS-3**: `logs/ns3.log`
- **Docker**: `docker logs <container-name>`

## 📊 性能指标

### 网络性能
- **延迟**: ~2ms (往返)
- **带宽**: 100Mbps
- **丢包率**: <5% (正常情况)

### 系统资源
- **内存**: ~2GB (所有服务)
- **CPU**: ~10% (空闲状态)
- **存储**: ~1GB (初始数据)

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 创建 Pull Request

## 📄 许可证

本项目基于 MIT 许可证开源。

## 🙏 致谢

- Prysm Labs - Beacon Chain 实现
- Go-Ethereum - 执行层客户端
- NS-3 - 网络模拟器
- Docker - 容器化平台