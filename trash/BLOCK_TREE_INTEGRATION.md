# 区块树可视化集成说明

区块树可视化功能已完全集成到主启动脚本 `main.sh` 中，提供了完整的以太坊测试网区块链结构可视化能力。

## 🚀 快速开始

### 1. 启动完整测试网（包含区块树可视化）
```bash
./main.sh
```

这将自动启动：
- ✅ Geth执行层客户端
- ✅ 4个Beacon Chain节点
- ✅ 4个Validator客户端
- ✅ Prometheus监控
- ✅ Grafana仪表板
- ✅ **区块树可视化器** (新增)
- ✅ NS-3网络模拟

### 2. 专门检查区块树可视化器状态
```bash
./main.sh visualizer
```

输出示例：
```
[INFO] 检查区块树可视化器状态...
[SUCCESS] 区块树可视化器容器正在运行
[SUCCESS] 区块树可视化器服务健康，活跃连接: 2
[SUCCESS] 已连接到 4 个beacon节点数据源

🌐 区块树可视化界面: http://localhost:8888
📊 Grafana仪表板: http://localhost:3000 (admin/admin)
📡 API接口: http://localhost:8888/api/fork-choice
```

### 3. 查看网络状态（已增强）
```bash
./main.sh status
```

现在包含区块树可视化器的状态信息。

### 4. 清理环境
```bash
./main.sh clean
```

自动清理所有服务，包括区块树可视化器。

## 🌐 访问界面

启动完成后，您可以访问：

| 服务 | 地址 | 说明 |
|------|------|------|
| **区块树可视化** | http://localhost:8888 | 动态区块树界面 |
| Grafana仪表板 | http://localhost:3000 | 监控面板 (admin/admin) |
| Prometheus | http://localhost:9090 | 指标收集 |
| Beacon-1 API | http://localhost:7777 | 主要beacon节点 |
| Geth RPC | http://localhost:8545 | 执行层RPC |

## 📊 区块树可视化功能

### 实时特性
- ✅ **动态更新**：每2秒自动刷新区块数据
- ✅ **WebSocket连接**：实时推送新区块信息
- ✅ **分叉检测**：自动识别和显示区块链分叉
- ✅ **状态跟踪**：追踪justification和finalization

### 可视化元素
- 🔴 **红色节点**：当前头部区块
- 🟢 **绿色节点**：已最终化区块
- 🟡 **黄色节点**：已确认区块
- 🟢 **浅绿节点**：普通区块
- ➡️ **连接线**：父子区块关系

### 交互功能
- 🖱️ **拖拽移动**：可拖拽节点调整布局
- 🔍 **缩放查看**：鼠标滚轮缩放，双击重置
- 💭 **悬停详情**：鼠标悬停查看区块详细信息
- 📋 **侧边栏**：按时间列出所有区块

## 🔧 高级功能

### API接口
```bash
# 获取当前fork choice数据
curl http://localhost:8888/api/fork-choice

# 检查服务健康状态
curl http://localhost:8888/health
```

### Grafana集成
新增的"区块树概览"仪表板包含：
- 头部槽位进展图表
- 最终化和确认Epoch统计
- 验证者参与率监控
- 分叉事件频率分析
- 直接链接到区块树可视化界面

### 服务监控
区块树可视化器已集成到Prometheus监控中：
- 健康状态检查
- 活跃连接数量
- 数据源连接状态
- 服务可用性监控

## 📋 集成详情

### main.sh 中的变化

1. **启动阶段**：
   - 在步骤1中启动区块树可视化器容器
   - 等待服务就绪后再继续

2. **状态检查**：
   - 新增 `check_block_tree_visualizer_status()` 函数
   - 验证容器运行状态和服务健康
   - 显示连接统计和访问链接

3. **命令增强**：
   - 新增 `./main.sh visualizer` 命令
   - 更新帮助信息包含可视化器
   - 状态显示包含可视化器端口

4. **清理功能**：
   - 自动清理独立运行的可视化器容器
   - 完整的环境重置

### Docker Compose集成
- 新增 `block-tree-visualizer` 服务
- 端口映射：8888:8000
- 依赖所有beacon节点
- 自动重启和健康检查

### Prometheus配置
- 添加可视化器到监控目标
- 健康检查端点：`/health`
- 自动服务发现

## 🐛 故障排除

### 常见问题

1. **可视化器无法启动**
   ```bash
   # 检查依赖服务
   docker-compose ps
   
   # 查看可视化器日志
   docker-compose logs block-tree-visualizer
   ```

2. **连接不到beacon节点**
   ```bash
   # 检查beacon节点状态
   ./main.sh status
   
   # 验证API可达性
   curl http://localhost:7777/eth/v1/node/health
   ```

3. **Web界面显示异常**
   - 刷新浏览器页面
   - 检查JavaScript控制台错误
   - 验证WebSocket连接

### 手动重启可视化器
```bash
# 重启可视化器服务
docker-compose restart block-tree-visualizer

# 查看启动日志
docker-compose logs -f block-tree-visualizer
```

## 🎯 使用建议

1. **首次启动**：等待所有服务完全启动（约2-3分钟）
2. **观察分叉**：可以通过停止部分validator观察分叉行为
3. **性能监控**：使用Grafana仪表板监控整体网络健康
4. **API开发**：使用fork-choice API进行自定义分析

区块树可视化器现在是测试网的核心组件，提供了前所未有的区块链结构洞察能力！
