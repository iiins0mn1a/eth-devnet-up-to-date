# 数据处理代码示例分析

## 🔍 Prometheus数据处理示例

### 1. 参与率计算
```promql
# 计算目标投票参与率
beacon_prev_epoch_target_gwei / beacon_prev_epoch_active_gwei

# 说明：
# - beacon_prev_epoch_target_gwei: 上一epoch中投票给目标的总权重(Gwei)
# - beacon_prev_epoch_active_gwei: 上一epoch中活跃验证者的总权重(Gwei)  
# - 结果: 0-1之间的比值，表示参与率百分比
```

### 2. 分叉频率计算
```promql
# 计算5分钟内的分叉频率
sum(rate(doublylinkedtree_head_changed_count[5m]))

# 说明：
# - doublylinkedtree_head_changed_count: 头部切换事件计数器
# - rate[5m]: 计算5分钟内的平均变化率
# - sum(): 对所有节点的变化率求和
# - 结果: 每秒的分叉事件数量
```

### 3. 延迟分位数计算
```promql
# 计算95%分位数的区块传播延迟
histogram_quantile(0.95, sum by (le) (rate(block_arrival_latency_milliseconds_bucket[5m])))

# 说明：
# - block_arrival_latency_milliseconds_bucket: 延迟直方图桶
# - rate[5m]: 计算5分钟内各桶的变化率
# - sum by (le): 按桶边界聚合
# - histogram_quantile(0.95, ...): 计算95%分位数
# - 结果: 95%的区块在X毫秒内传播完成
```

## 🌳 Fork Choice数据处理示例

### 1. Python后端数据解析
```python
def _parse_fork_choice_data(self, raw_data: dict) -> ForkChoiceData:
    """解析原始fork choice数据"""
    nodes = []
    
    # 处理每个区块节点
    for node_data in raw_data.get('fork_choice_nodes', []):
        extra_data = node_data.get('extra_data', {})
        
        # 创建结构化的区块节点对象
        node = BlockNode(
            slot=node_data.get('slot', '0'),                    # 槽位号
            block_root=node_data.get('block_root', ''),         # 区块哈希
            parent_root=node_data.get('parent_root', ''),       # 父区块哈希
            justified_epoch=node_data.get('justified_epoch', '0'), # 确认epoch
            finalized_epoch=node_data.get('finalized_epoch', '0'), # 最终化epoch
            weight=node_data.get('weight', '0'),                # 验证者权重
            validity=node_data.get('validity', 'unknown'),      # 有效性状态
            execution_block_hash=node_data.get('execution_block_hash', ''), # 执行层哈希
            timestamp=extra_data.get('timestamp', str(int(time.time()))), # 时间戳
            # ... 更多字段
        )
        nodes.append(node)
    
    # 创建完整的Fork Choice数据结构
    return ForkChoiceData(
        justified_checkpoint=raw_data.get('justified_checkpoint', {}),
        finalized_checkpoint=raw_data.get('finalized_checkpoint', {}),
        nodes=nodes,
        head_root=extra_data.get('head_root', ''),
        # ... 更多字段
    )
```

### 2. JavaScript前端数据处理
```javascript
processData(endpointData) {
    const { nodes, head_root, finalized_checkpoint, justified_checkpoint } = endpointData;
    const finalizedEpoch = parseInt(finalized_checkpoint.epoch || '0');
    const justifiedEpoch = parseInt(justified_checkpoint.epoch || '0');
    
    // 构建可视化节点数据
    this.nodes = nodes.map(node => ({
        id: node.block_root,                    // 唯一标识
        slot: parseInt(node.slot),              // 槽位号(数值)
        hash: node.block_root,                  // 完整哈希
        parent: node.parent_root,               // 父节点引用
        weight: parseInt(node.weight),          // 权重(数值)
        validity: node.validity,                // 有效性状态
        justifiedEpoch: parseInt(node.justified_epoch),
        finalizedEpoch: parseInt(node.finalized_epoch),
        
        // 状态判断(布尔值)
        isHead: node.block_root === head_root,  // 是否为当前头部
        isFinalized: parseInt(node.finalized_epoch) >= finalizedEpoch, // 是否已最终化
        isJustified: parseInt(node.justified_epoch) >= justifiedEpoch, // 是否已确认
        
        timestamp: parseInt(node.timestamp),
        balance: parseInt(node.balance || '0')
    }));
    
    // 构建节点连接关系
    this.links = [];
    const nodeMap = new Map(this.nodes.map(n => [n.id, n]));
    
    this.nodes.forEach(node => {
        // 跳过创世区块(没有父节点)
        if (node.parent && node.parent !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
            const parentNode = nodeMap.get(node.parent);
            if (parentNode) {
                this.links.push({
                    source: node.parent,        // 源节点ID
                    target: node.id,           // 目标节点ID
                    isFinalized: node.isFinalized && parentNode.isFinalized // 连接的最终化状态
                });
            }
        }
    });
}
```

### 3. 可视化渲染逻辑
```javascript
renderTree() {
    // 创建力导向图模拟
    this.simulation = d3.forceSimulation(this.nodes)
        .force('link', d3.forceLink(this.links).id(d => d.id).distance(80))  // 连接力
        .force('charge', d3.forceManyBody().strength(-200))                   // 排斥力
        .force('center', d3.forceCenter(width / 2, height / 2))              // 中心力
        .force('collision', d3.forceCollide().radius(15));                   // 碰撞检测
    
    // 绘制连接线
    const link = this.g.append('g')
        .selectAll('line')
        .data(this.links)
        .enter().append('line')
        .attr('class', d => `link ${d.isFinalized ? 'finalized' : ''}`)
        .attr('stroke-width', d => d.isFinalized ? 3 : 2);  // 最终化连接更粗
    
    // 绘制节点
    const node = this.g.append('g')
        .selectAll('.node')
        .data(this.nodes)
        .enter().append('g')
        .attr('class', 'node');
    
    // 添加节点圆圈 - 根据状态着色
    node.append('circle')
        .attr('r', d => Math.max(8, Math.min(15, Math.log(d.weight / 1e9 + 1) * 3))) // 权重决定大小
        .attr('fill', d => {
            if (d.isHead) return '#FF6B6B';        // 红色: 当前头部
            if (d.isFinalized) return '#4ECDC4';   // 绿色: 已最终化
            if (d.isJustified) return '#FFE66D';   // 黄色: 已确认
            return '#A8E6CF';                      // 浅绿: 普通区块
        })
        .attr('stroke', '#ffffff')
        .attr('stroke-width', d => d.isHead ? 3 : 2); // 头部节点边框更粗
    
    // 添加节点标签
    node.append('text')
        .text(d => `S${d.slot}`)                   // 显示槽位号
        .attr('dy', 4)
        .style('font-size', '10px')
        .style('font-weight', 'bold');
}
```

## 📊 数据更新机制

### 1. Prometheus数据流
```yaml
# prometheus.yml 配置
global:
  scrape_interval: 5s          # 每5秒抓取一次
  evaluation_interval: 5s      # 每5秒评估一次规则

scrape_configs:
  - job_name: prysm-beacon
    static_configs:
      - targets:
          - "beacon-chain-1:8080"  # beacon节点指标端点
          - "beacon-chain-2:8080"
          - "beacon-chain-3:8080" 
          - "beacon-chain-4:8080"
```

### 2. 区块树数据流
```python
async def start_collection_loop(self):
    """数据收集循环"""
    while True:
        try:
            # 从所有beacon节点收集fork choice数据
            self.latest_data = await self.collect_fork_choice_data()
            
            # 通过WebSocket广播给所有连接的客户端
            await self._broadcast_update()
            
            # 每2秒更新一次
            await asyncio.sleep(2)
        except Exception as e:
            logger.error(f"数据收集错误: {e}")
            await asyncio.sleep(5)
```

### 3. WebSocket实时推送
```javascript
// 前端WebSocket连接
initWebSocket() {
    this.websocket = new WebSocket(`ws://${window.location.host}/ws`);
    
    this.websocket.onmessage = (event) => {
        const message = JSON.parse(event.data);
        
        if (message.type === 'fork_choice_update') {
            this.data = message.data;           // 更新数据
            this.updateVisualization();         // 重绘可视化
            this.updateStatusBar();             // 更新状态栏
            this.updateNodeList();              // 更新节点列表
        }
    };
}
```

## 🎯 关键数据指标含义

### Prometheus指标详解

| 指标名称 | 数据类型 | 含义 | 用途 |
|---------|---------|------|------|
| `beacon_head_slot` | Gauge | 当前头部槽位 | 区块链进展监控 |
| `beacon_finalized_epoch` | Gauge | 最终化的epoch | 网络稳定性指标 |
| `beacon_justified_epoch` | Gauge | 确认的epoch | 网络一致性指标 |
| `beacon_prev_epoch_target_gwei` | Gauge | 目标投票权重 | 参与率计算分子 |
| `beacon_prev_epoch_active_gwei` | Gauge | 活跃验证者权重 | 参与率计算分母 |
| `doublylinkedtree_head_changed_count` | Counter | 头部切换次数 | 分叉频率监控 |
| `attestation_inclusion_delay_slots_bucket` | Histogram | 证明包含延迟 | 网络性能分析 |
| `block_arrival_latency_milliseconds_bucket` | Histogram | 区块传播延迟 | 网络延迟分析 |

### Fork Choice数据结构

```json
{
  "justified_checkpoint": {
    "epoch": "0",
    "root": "0x..."
  },
  "finalized_checkpoint": {  
    "epoch": "0",
    "root": "0x..."
  },
  "fork_choice_nodes": [
    {
      "slot": "10",
      "block_root": "0x...",
      "parent_root": "0x...",
      "justified_epoch": "0",
      "finalized_epoch": "0", 
      "weight": "1888000000000",
      "validity": "valid",
      "execution_block_hash": "0x...",
      "extra_data": {
        "unrealized_justified_epoch": "0",
        "unrealized_finalized_epoch": "0",
        "balance": "96000000000",
        "execution_optimistic": false,
        "timestamp": "1754903026",
        "target": "0x..."
      }
    }
  ],
  "extra_data": {
    "head_root": "0x...",
    "proposer_boost_root": "0x...",
    "previous_proposer_boost_root": "0x..."
  }
}
```

这两种数据源和处理方式为您的以太坊测试网提供了全面的监控和可视化能力，既有传统的性能指标监控，又有直观的区块链结构展示。
