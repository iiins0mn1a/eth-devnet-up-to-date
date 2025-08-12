/**
 * 以太坊测试网区块树可视化组件
 * 动态展示fork choice数据，包含justification和finalization信息
 */

class BlockTreeVisualizer {
    constructor() {
        this.websocket = null;
        this.data = {};
        this.svg = null;
        this.nodes = [];
        this.links = [];
        this.simulation = null;
        this.currentEndpoint = 'all';
        this.autoRefresh = false;
        this.refreshInterval = null;
        this.isRefreshing = false;
        
        this.initWebSocket();
        this.initSVG();
        this.setupEventListeners();
        this.setupControls();
    }

    initWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        console.log('连接WebSocket:', wsUrl);
        this.websocket = new WebSocket(wsUrl);
        
        this.websocket.onopen = () => {
            console.log('WebSocket已连接');
            this.updateConnectionStatus(true);
        };
        
        this.websocket.onmessage = (event) => {
            try {
                const message = JSON.parse(event.data);
                this.handleWebSocketMessage(message);
            } catch (error) {
                console.error('解析WebSocket消息失败:', error);
            }
        };
        
        this.websocket.onclose = () => {
            console.log('WebSocket连接已关闭');
            this.updateConnectionStatus(false);
            // 5秒后尝试重连
            setTimeout(() => this.initWebSocket(), 5000);
        };
        
        this.websocket.onerror = (error) => {
            console.error('WebSocket错误:', error);
            this.updateConnectionStatus(false);
        };
    }

    initSVG() {
        this.svg = d3.select('#block-tree-svg');
        
        // 定义箭头标记
        this.svg.append('defs').append('marker')
            .attr('id', 'arrowhead')
            .attr('viewBox', '0 -5 10 10')
            .attr('refX', 20)
            .attr('refY', 0)
            .attr('markerWidth', 6)
            .attr('markerHeight', 6)
            .attr('orient', 'auto')
            .append('path')
            .attr('d', 'M0,-5L10,0L0,5')
            .attr('fill', 'rgba(255, 255, 255, 0.6)');

        // 创建容器组
        this.g = this.svg.append('g');
        
        // 添加缩放功能
        const zoom = d3.zoom()
            .scaleExtent([0.1, 5])
            .on('zoom', (event) => {
                this.g.attr('transform', event.transform);
            });
        
        this.svg.call(zoom);
        
        // 添加双击重置缩放
        this.svg.on('dblclick.zoom', () => {
            this.svg.transition().duration(750).call(
                zoom.transform,
                d3.zoomIdentity
            );
        });
    }

    setupEventListeners() {
        // 窗口大小变化时重新绘制
        window.addEventListener('resize', () => {
            this.updateVisualization();
        });
    }

    handleWebSocketMessage(message) {
        console.log('收到WebSocket消息:', message.type);
        
        if (message.type === 'initial_data' || message.type === 'fork_choice_update') {
            // 存储最新数据
            this.data = message.data;
            
            // 只在自动刷新模式下或者是初始数据时更新可视化
            if (this.autoRefresh || message.type === 'initial_data') {
                this.updateVisualization();
                this.updateStatusBar();
                this.updateNodeList();
                
                // 更新最后更新时间
                const now = new Date();
                document.getElementById('last-update').textContent = 
                    now.toLocaleTimeString('zh-CN');
            }
        }
    }

    updateConnectionStatus(connected) {
        const statusElement = document.getElementById('ws-status');
        const connectionStatusElement = document.getElementById('connection-status');
        
        if (connected) {
            statusElement.textContent = '已连接';
            statusElement.className = 'connection-status connected';
            connectionStatusElement.textContent = '已连接';
        } else {
            statusElement.textContent = '未连接';
            statusElement.className = 'connection-status disconnected';
            connectionStatusElement.textContent = '断开连接';
        }
    }

    updateStatusBar() {
        if (!this.data || Object.keys(this.data).length === 0) return;
        
        let selectedData;
        
        if (this.currentEndpoint === 'all') {
            selectedData = Object.values(this.data)[0];
        } else {
            const fullEndpoint = `http://${this.currentEndpoint}`;
            selectedData = this.data[fullEndpoint];
            if (!selectedData) {
                selectedData = Object.values(this.data)[0];
            }
        }
        
        if (!selectedData) return;
        
        const { nodes, head_root, finalized_checkpoint } = selectedData;
        
        // 找到头部节点
        const headNode = nodes.find(node => node.block_root === head_root);
        const headSlot = headNode ? headNode.slot : '-';
        
        // 更新状态栏
        document.getElementById('head-slot').textContent = headSlot;
        document.getElementById('finalized-epoch').textContent = 
            finalized_checkpoint.epoch || '0';
        document.getElementById('active-nodes').textContent = nodes.length;
        
        // 更新连接状态，显示当前选择的节点
        const nodeInfo = this.currentEndpoint === 'all' ? '所有节点' : this.currentEndpoint;
        document.getElementById('connection-status').textContent = 
            `已连接 (${nodeInfo})`;
    }

    updateNodeList() {
        const nodeListElement = document.getElementById('node-list');
        nodeListElement.innerHTML = '';
        
        if (!this.data || Object.keys(this.data).length === 0) return;
        
        let selectedData;
        
        if (this.currentEndpoint === 'all') {
            selectedData = Object.values(this.data)[0];
        } else {
            const fullEndpoint = `http://${this.currentEndpoint}`;
            selectedData = this.data[fullEndpoint];
            if (!selectedData) {
                selectedData = Object.values(this.data)[0];
            }
        }
        
        if (!selectedData) return;
        
        const { nodes, head_root, finalized_checkpoint } = selectedData;
        const finalizedEpoch = parseInt(finalized_checkpoint.epoch || '0');
        
        // 按槽位排序
        const sortedNodes = [...nodes].sort((a, b) => parseInt(b.slot) - parseInt(a.slot));
        
        sortedNodes.forEach(node => {
            const nodeElement = document.createElement('div');
            nodeElement.className = 'node-item';
            
            // 添加特殊样式
            if (node.block_root === head_root) {
                nodeElement.classList.add('head');
            }
            if (parseInt(node.finalized_epoch) >= finalizedEpoch) {
                nodeElement.classList.add('finalized');
            }
            
            nodeElement.innerHTML = `
                <div class="node-slot">Slot ${node.slot}</div>
                <div class="node-hash">${node.block_root.substring(0, 16)}...</div>
                <div class="node-details">
                    <div>权重: ${this.formatWeight(node.weight)}</div>
                    <div>状态: ${node.validity}</div>
                    <div>确认Epoch: ${node.justified_epoch}</div>
                </div>
            `;
            
            // 点击时高亮对应的可视化节点
            nodeElement.addEventListener('click', () => {
                this.highlightNode(node.block_root);
            });
            
            nodeListElement.appendChild(nodeElement);
        });
    }

    formatWeight(weight) {
        const num = parseInt(weight);
        if (num >= 1e12) return (num / 1e12).toFixed(1) + 'T';
        if (num >= 1e9) return (num / 1e9).toFixed(1) + 'B';
        if (num >= 1e6) return (num / 1e6).toFixed(1) + 'M';
        if (num >= 1e3) return (num / 1e3).toFixed(1) + 'K';
        return num.toString();
    }

    setupControls() {
        // 节点选择器
        const nodeSelector = document.getElementById('node-selector');
        nodeSelector.addEventListener('change', (e) => {
            this.currentEndpoint = e.target.value;
            this.updateVisualization();
        });

        // 手动刷新按钮
        const refreshBtn = document.getElementById('refresh-btn');
        refreshBtn.addEventListener('click', () => {
            this.manualRefresh();
        });

        // 自动刷新开关
        const autoRefreshToggle = document.getElementById('auto-refresh-toggle');
        autoRefreshToggle.addEventListener('click', () => {
            this.toggleAutoRefresh();
        });
    }

    manualRefresh() {
        if (this.isRefreshing) return;
        
        this.isRefreshing = true;
        const refreshBtn = document.getElementById('refresh-btn');
        refreshBtn.disabled = true;
        refreshBtn.textContent = '🔄 刷新中...';

        // 更新可视化
        this.updateVisualization();
        this.updateStatusBar();
        this.updateNodeList();

        // 更新时间
        const now = new Date();
        document.getElementById('last-update').textContent = 
            now.toLocaleTimeString('zh-CN');

        // 恢复按钮状态
        setTimeout(() => {
            this.isRefreshing = false;
            refreshBtn.disabled = false;
            refreshBtn.textContent = '🔄 手动刷新';
        }, 500);
    }

    toggleAutoRefresh() {
        this.autoRefresh = !this.autoRefresh;
        const toggle = document.getElementById('auto-refresh-toggle');
        
        if (this.autoRefresh) {
            toggle.classList.add('active');
        } else {
            toggle.classList.remove('active');
        }

        console.log('自动刷新模式:', this.autoRefresh ? '开启' : '关闭');
    }

    updateVisualization() {
        if (!this.data || Object.keys(this.data).length === 0) return;
        
        let selectedData;
        
        if (this.currentEndpoint === 'all') {
            // 使用第一个可用的节点数据
            selectedData = Object.values(this.data)[0];
        } else {
            // 使用指定节点的数据
            const fullEndpoint = `http://${this.currentEndpoint}`;
            selectedData = this.data[fullEndpoint];
            
            if (!selectedData) {
                console.warn(`未找到节点 ${this.currentEndpoint} 的数据`);
                selectedData = Object.values(this.data)[0];
            }
        }
        
        if (!selectedData) return;
        
        this.processData(selectedData);
        this.renderTree();
    }

    processData(endpointData) {
        const { nodes, head_root, finalized_checkpoint, justified_checkpoint } = endpointData;
        const finalizedEpoch = parseInt(finalized_checkpoint.epoch || '0');
        const justifiedEpoch = parseInt(justified_checkpoint.epoch || '0');
        
        // 构建节点数据
        this.nodes = nodes.map(node => ({
            id: node.block_root,
            slot: parseInt(node.slot),
            hash: node.block_root,
            parent: node.parent_root,
            weight: parseInt(node.weight),
            validity: node.validity,
            justifiedEpoch: parseInt(node.justified_epoch),
            finalizedEpoch: parseInt(node.finalized_epoch),
            isHead: node.block_root === head_root,
            isFinalized: parseInt(node.finalized_epoch) >= finalizedEpoch,
            isJustified: parseInt(node.justified_epoch) >= justifiedEpoch,
            timestamp: parseInt(node.timestamp),
            balance: parseInt(node.balance || '0')
        }));
        
        // 构建连接数据
        this.links = [];
        const nodeMap = new Map(this.nodes.map(n => [n.id, n]));
        
        this.nodes.forEach(node => {
            if (node.parent && node.parent !== '0x0000000000000000000000000000000000000000000000000000000000000000') {
                const parentNode = nodeMap.get(node.parent);
                if (parentNode) {
                    this.links.push({
                        source: node.parent,
                        target: node.id,
                        isFinalized: node.isFinalized && parentNode.isFinalized
                    });
                }
            }
        });
        
        console.log(`处理了 ${this.nodes.length} 个节点和 ${this.links.length} 个连接`);
    }

    renderTree() {
        const width = this.svg.node().clientWidth;
        const height = this.svg.node().clientHeight;
        
        // 停止之前的模拟
        if (this.simulation) {
            this.simulation.stop();
        }
        
        // 清除之前的内容
        this.g.selectAll('*').remove();
        
        // 创建稳定的力导向图模拟
        this.simulation = d3.forceSimulation(this.nodes)
            .force('link', d3.forceLink(this.links).id(d => d.id).distance(100))
            .force('charge', d3.forceManyBody().strength(-300))
            .force('center', d3.forceCenter(width / 2, height / 2))
            .force('y', d3.forceY().strength(0.05))
            .force('collision', d3.forceCollide().radius(20))
            .alphaDecay(0.01)  // 更慢的衰减，更稳定的布局
            .velocityDecay(0.3);  // 更高的速度衰减，减少震荡
        
        // 绘制连接线
        const link = this.g.append('g')
            .selectAll('line')
            .data(this.links)
            .enter().append('line')
            .attr('class', d => `link ${d.isFinalized ? 'finalized' : ''}`)
            .attr('stroke-width', d => d.isFinalized ? 3 : 2);
        
        // 绘制节点
        const node = this.g.append('g')
            .selectAll('.node')
            .data(this.nodes)
            .enter().append('g')
            .attr('class', 'node')
            .call(d3.drag()
                .on('start', (event, d) => {
                    if (!event.active) this.simulation.alphaTarget(0.3).restart();
                    d.fx = d.x;
                    d.fy = d.y;
                })
                .on('drag', (event, d) => {
                    d.fx = event.x;
                    d.fy = event.y;
                })
                .on('end', (event, d) => {
                    if (!event.active) this.simulation.alphaTarget(0);
                    d.fx = null;
                    d.fy = null;
                }));
        
        // 添加节点圆圈
        node.append('circle')
            .attr('r', d => Math.max(8, Math.min(15, Math.log(d.weight / 1e9 + 1) * 3)))
            .attr('fill', d => {
                if (d.isHead) return '#FF6B6B';
                if (d.isFinalized) return '#4ECDC4';
                if (d.isJustified) return '#FFE66D';
                return '#A8E6CF';
            })
            .attr('stroke', '#ffffff')
            .attr('stroke-width', d => d.isHead ? 3 : 2);
        
        // 添加节点标签
        node.append('text')
            .text(d => `S${d.slot}`)
            .attr('dy', 4)
            .style('font-size', '10px')
            .style('font-weight', 'bold');
        
        // 添加悬停提示
        node.on('mouseover', (event, d) => {
            this.showTooltip(event, d);
        }).on('mouseout', () => {
            this.hideTooltip();
        });
        
        // 更新模拟
        this.simulation.on('tick', () => {
            link
                .attr('x1', d => d.source.x)
                .attr('y1', d => d.source.y)
                .attr('x2', d => d.target.x)
                .attr('y2', d => d.target.y);
            
            node
                .attr('transform', d => `translate(${d.x},${d.y})`);
        });
    }

    showTooltip(event, node) {
        const tooltip = document.getElementById('tooltip');
        const date = new Date(node.timestamp * 1000);
        
        tooltip.innerHTML = `
            <strong>区块信息</strong><br/>
            <strong>槽位:</strong> ${node.slot}<br/>
            <strong>哈希:</strong> ${node.hash.substring(0, 20)}...<br/>
            <strong>权重:</strong> ${this.formatWeight(node.weight.toString())}<br/>
            <strong>状态:</strong> ${node.validity}<br/>
            <strong>确认Epoch:</strong> ${node.justifiedEpoch}<br/>
            <strong>最终化Epoch:</strong> ${node.finalizedEpoch}<br/>
            <strong>余额:</strong> ${this.formatWeight(node.balance.toString())}<br/>
            <strong>时间戳:</strong> ${date.toLocaleString('zh-CN')}<br/>
            ${node.isHead ? '<strong style="color: #FF6B6B;">🎯 当前头部</strong><br/>' : ''}
            ${node.isFinalized ? '<strong style="color: #4ECDC4;">✅ 已最终化</strong><br/>' : ''}
            ${node.isJustified ? '<strong style="color: #FFE66D;">⚡ 已确认</strong>' : ''}
        `;
        
        tooltip.style.display = 'block';
        tooltip.style.left = (event.pageX + 10) + 'px';
        tooltip.style.top = (event.pageY - 10) + 'px';
    }

    hideTooltip() {
        document.getElementById('tooltip').style.display = 'none';
    }

    highlightNode(blockRoot) {
        this.g.selectAll('.node circle')
            .transition()
            .duration(200)
            .attr('stroke-width', d => d.id === blockRoot ? 5 : (d.isHead ? 3 : 2))
            .attr('r', d => {
                const baseRadius = Math.max(8, Math.min(15, Math.log(d.weight / 1e9 + 1) * 3));
                return d.id === blockRoot ? baseRadius + 3 : baseRadius;
            });
        
        // 3秒后恢复正常样式
        setTimeout(() => {
            this.g.selectAll('.node circle')
                .transition()
                .duration(200)
                .attr('stroke-width', d => d.isHead ? 3 : 2)
                .attr('r', d => Math.max(8, Math.min(15, Math.log(d.weight / 1e9 + 1) * 3)));
        }, 3000);
    }
}

// 页面加载完成后初始化可视化
document.addEventListener('DOMContentLoaded', () => {
    console.log('初始化区块树可视化器...');
    new BlockTreeVisualizer();
});
