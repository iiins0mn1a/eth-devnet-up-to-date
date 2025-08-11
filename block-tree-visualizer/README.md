# 以太坊测试网区块树可视化器

这是一个专为以太坊PoS测试网设计的动态区块树可视化系统，能够实时展示区块链结构、分叉状态和最终化进程。

## 功能特色

### 🔄 实时数据收集
- 每2秒从所有beacon节点收集fork_choice数据
- 通过WebSocket实时推送更新
- 支持多节点数据源自动切换

### 🌳 动态区块树可视化
- **交互式区块树**：使用D3.js力导向图展示区块结构
- **实时更新**：新区块自动添加到可视化中
- **分叉展示**：清晰显示链的分叉和合并
- **拖拽交互**：支持节点拖拽和缩放

### ✅ 最终化状态跟踪
- **颜色编码**：
  - 🔴 红色：当前头部区块
  - 🟢 绿色：已最终化区块
  - 🟡 黄色：已确认区块
  - 🟢 浅绿：普通区块
- **状态信息**：显示justification和finalization状态
- **权重显示**：根据验证者权重调整节点大小

### 📊 详细信息展示
- **悬停提示**：显示区块详细信息
- **侧边栏列表**：按时间顺序列出所有区块
- **状态栏**：实时显示网络状态统计

## 快速开始

### 1. 构建和运行
该服务已集成到主Docker Compose配置中：

```bash
# 启动整个测试网（包括区块树可视化）
docker-compose up -d

# 查看区块树可视化服务日志
docker-compose logs -f block-tree-visualizer
```

### 2. 访问界面
- **Web可视化界面**：http://localhost:8888
- **健康检查API**：http://localhost:8888/health
- **Fork Choice API**：http://localhost:8888/api/fork-choice

### 3. Grafana集成
访问Grafana仪表板：http://localhost:3000
- 用户名：admin
- 密码：admin
- 查看"区块树概览"仪表板

## API接口

### WebSocket接口
```
ws://localhost:8888/ws
```
实时接收fork choice数据更新

### REST API

#### GET /health
返回服务健康状态
```json
{
  "status": "healthy",
  "timestamp": 1640995200.0,
  "active_connections": 2,
  "data_sources": 4
}
```

#### GET /api/fork-choice
返回所有beacon节点的当前fork choice数据
```json
{
  "http://beacon-chain-1:7777": {
    "justified_checkpoint": {...},
    "finalized_checkpoint": {...},
    "head_root": "0x...",
    "nodes": [...],
    "timestamp": 1640995200.0
  }
}
```

## 数据结构

### 区块节点
每个区块节点包含以下信息：
- `slot`: 槽位号
- `block_root`: 区块哈希
- `parent_root`: 父区块哈希
- `justified_epoch`: 确认的epoch
- `finalized_epoch`: 最终化的epoch
- `weight`: 验证者权重
- `validity`: 区块有效性
- `timestamp`: 时间戳
- `balance`: 余额

### Fork Choice数据
包含整个区块树的状态：
- `justified_checkpoint`: 当前确认检查点
- `finalized_checkpoint`: 当前最终化检查点
- `head_root`: 当前头部区块
- `nodes`: 所有区块节点列表

## 技术架构

### 后端 (Python)
- **异步框架**：aiohttp
- **数据收集**：定期轮询beacon节点
- **WebSocket**：实时数据推送
- **健康检查**：服务状态监控

### 前端 (JavaScript)
- **可视化库**：D3.js
- **实时通信**：WebSocket
- **响应式设计**：支持移动设备
- **交互功能**：缩放、拖拽、悬停

### 集成
- **Docker容器化**：完整的容器化部署
- **Prometheus监控**：服务状态指标
- **Grafana仪表板**：监控数据可视化

## 配置选项

### 环境变量
- `BEACON_ENDPOINTS`: beacon节点端点列表（逗号分隔）

### Docker Compose配置
```yaml
block-tree-visualizer:
  build: ./block-tree-visualizer
  ports:
    - "8888:8000"
  environment:
    - BEACON_ENDPOINTS=http://beacon-chain-1:7777,http://beacon-chain-2:7777
```

## 故障排除

### 常见问题

1. **连接失败**
   - 检查beacon节点是否正常运行
   - 验证网络连接和端口配置

2. **数据不更新**
   - 查看服务日志：`docker-compose logs block-tree-visualizer`
   - 检查beacon节点的fork_choice API是否可访问

3. **可视化显示异常**
   - 刷新浏览器页面
   - 检查JavaScript控制台错误

### 日志级别
服务默认使用INFO级别日志，可以通过修改`server.py`中的logging配置调整。

## 开发指南

### 本地开发
```bash
# 安装依赖
pip install -r requirements.txt

# 运行开发服务器
python server.py

# 或使用热重载
python -m aiohttp.web -H 0.0.0.0 -P 8000 server:init_app
```

### 代码结构
```
block-tree-visualizer/
├── server.py              # 主服务器代码
├── static/
│   ├── index.html         # 主页面
│   └── block-tree.js      # 可视化逻辑
├── Dockerfile             # 容器化配置
├── requirements.txt       # Python依赖
└── README.md             # 文档
```

## 许可证

本项目采用MIT许可证，详见LICENSE文件。

## 贡献

欢迎提交问题报告和功能请求！请遵循项目的代码规范和提交指南。
