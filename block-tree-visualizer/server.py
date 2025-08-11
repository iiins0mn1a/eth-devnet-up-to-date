#!/usr/bin/env python3
"""
以太坊测试网区块树可视化服务器
从beacon节点收集fork_choice数据，提供实时区块树可视化
"""

import asyncio
import json
import time
import logging
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Dict, List, Optional, Set
import aiohttp
from aiohttp import web, WSMsgType
import weakref

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@dataclass
class BlockNode:
    """区块节点数据结构"""
    slot: str
    block_root: str
    parent_root: str
    justified_epoch: str
    finalized_epoch: str
    weight: str
    validity: str
    execution_block_hash: str
    timestamp: str
    target: str
    # 额外的状态信息
    unrealized_justified_epoch: str = "0"
    unrealized_finalized_epoch: str = "0"
    balance: str = "0"
    execution_optimistic: bool = False

@dataclass
class ForkChoiceData:
    """Fork Choice数据结构"""
    justified_checkpoint: Dict[str, str]
    finalized_checkpoint: Dict[str, str]
    nodes: List[BlockNode]
    head_root: str
    unrealized_justified_checkpoint: Dict[str, str]
    unrealized_finalized_checkpoint: Dict[str, str]
    proposer_boost_root: str
    previous_proposer_boost_root: str
    timestamp: float

class BlockTreeCollector:
    """区块树数据收集器"""
    
    def __init__(self, beacon_endpoints: List[str]):
        self.beacon_endpoints = beacon_endpoints
        self.latest_data: Dict[str, ForkChoiceData] = {}
        self.websocket_connections: Set[web.WebSocketResponse] = weakref.WeakSet()
        
    async def collect_fork_choice_data(self) -> Dict[str, ForkChoiceData]:
        """从所有beacon节点收集fork choice数据"""
        results = {}
        
        async with aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=5)) as session:
            for endpoint in self.beacon_endpoints:
                try:
                    url = f"{endpoint}/eth/v1/debug/fork_choice"
                    async with session.get(url) as response:
                        if response.status == 200:
                            data = await response.json()
                            results[endpoint] = self._parse_fork_choice_data(data)
                            logger.info(f"成功收集 {endpoint} 的数据，包含 {len(data.get('fork_choice_nodes', []))} 个节点")
                        else:
                            logger.warning(f"从 {endpoint} 获取数据失败: HTTP {response.status}")
                except Exception as e:
                    logger.error(f"收集 {endpoint} 数据时发生错误: {e}")
                    
        return results
    
    def _parse_fork_choice_data(self, raw_data: dict) -> ForkChoiceData:
        """解析原始fork choice数据"""
        nodes = []
        for node_data in raw_data.get('fork_choice_nodes', []):
            extra_data = node_data.get('extra_data', {})
            node = BlockNode(
                slot=node_data.get('slot', '0'),
                block_root=node_data.get('block_root', ''),
                parent_root=node_data.get('parent_root', ''),
                justified_epoch=node_data.get('justified_epoch', '0'),
                finalized_epoch=node_data.get('finalized_epoch', '0'),
                weight=node_data.get('weight', '0'),
                validity=node_data.get('validity', 'unknown'),
                execution_block_hash=node_data.get('execution_block_hash', ''),
                timestamp=extra_data.get('timestamp', str(int(time.time()))),
                target=extra_data.get('target', ''),
                unrealized_justified_epoch=extra_data.get('unrealized_justified_epoch', '0'),
                unrealized_finalized_epoch=extra_data.get('unrealized_finalized_epoch', '0'),
                balance=extra_data.get('balance', '0'),
                execution_optimistic=extra_data.get('execution_optimistic', False)
            )
            nodes.append(node)
        
        extra_data = raw_data.get('extra_data', {})
        return ForkChoiceData(
            justified_checkpoint=raw_data.get('justified_checkpoint', {}),
            finalized_checkpoint=raw_data.get('finalized_checkpoint', {}),
            nodes=nodes,
            head_root=extra_data.get('head_root', ''),
            unrealized_justified_checkpoint=extra_data.get('unrealized_justified_checkpoint', {}),
            unrealized_finalized_checkpoint=extra_data.get('unrealized_finalized_checkpoint', {}),
            proposer_boost_root=extra_data.get('proposer_boost_root', ''),
            previous_proposer_boost_root=extra_data.get('previous_proposer_boost_root', ''),
            timestamp=time.time()
        )
    
    async def start_collection_loop(self):
        """开始数据收集循环"""
        while True:
            try:
                self.latest_data = await self.collect_fork_choice_data()
                await self._broadcast_update()
                await asyncio.sleep(2)  # 每2秒收集一次数据
            except Exception as e:
                logger.error(f"数据收集循环中发生错误: {e}")
                await asyncio.sleep(5)
    
    async def _broadcast_update(self):
        """向所有WebSocket连接广播更新"""
        if not self.latest_data:
            return
            
        # 准备要发送的数据
        broadcast_data = {
            'type': 'fork_choice_update',
            'timestamp': time.time(),
            'data': {}
        }
        
        for endpoint, fork_data in self.latest_data.items():
            broadcast_data['data'][endpoint] = {
                'justified_checkpoint': fork_data.justified_checkpoint,
                'finalized_checkpoint': fork_data.finalized_checkpoint,
                'head_root': fork_data.head_root,
                'nodes': [asdict(node) for node in fork_data.nodes],
                'timestamp': fork_data.timestamp
            }
        
        # 移除已断开的连接
        dead_connections = []
        for ws in list(self.websocket_connections):
            try:
                if ws.closed:
                    dead_connections.append(ws)
                else:
                    await ws.send_str(json.dumps(broadcast_data))
            except Exception as e:
                logger.warning(f"发送WebSocket消息失败: {e}")
                dead_connections.append(ws)
        
        # 清理断开的连接
        for ws in dead_connections:
            if ws in self.websocket_connections:
                self.websocket_connections.discard(ws)

# 从环境变量获取beacon端点
import os
BEACON_ENDPOINTS = os.environ.get(
    'BEACON_ENDPOINTS', 
    'http://beacon-chain-1:7777,http://beacon-chain-2:7777,http://beacon-chain-3:7777,http://beacon-chain-4:7777'
).split(',')

# 全局收集器实例
collector = BlockTreeCollector(BEACON_ENDPOINTS)

async def websocket_handler(request):
    """WebSocket连接处理器"""
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    
    collector.websocket_connections.add(ws)
    logger.info("新的WebSocket连接已建立")
    
    try:
        # 发送当前数据
        if collector.latest_data:
            initial_data = {
                'type': 'initial_data',
                'timestamp': time.time(),
                'data': {}
            }
            
            for endpoint, fork_data in collector.latest_data.items():
                initial_data['data'][endpoint] = {
                    'justified_checkpoint': fork_data.justified_checkpoint,
                    'finalized_checkpoint': fork_data.finalized_checkpoint,
                    'head_root': fork_data.head_root,
                    'nodes': [asdict(node) for node in fork_data.nodes],
                    'timestamp': fork_data.timestamp
                }
            
            await ws.send_str(json.dumps(initial_data))
        
        # 保持连接活跃
        async for msg in ws:
            if msg.type == WSMsgType.ERROR:
                logger.error(f'WebSocket错误: {ws.exception()}')
                break
            elif msg.type == WSMsgType.CLOSE:
                break
                
    except Exception as e:
        logger.error(f"WebSocket处理错误: {e}")
    finally:
        logger.info("WebSocket连接已关闭")
        
    return ws

async def api_fork_choice(request):
    """REST API: 获取fork choice数据"""
    try:
        if not collector.latest_data:
            return web.json_response({'error': '暂无数据'}, status=503)
        
        response_data = {}
        for endpoint, fork_data in collector.latest_data.items():
            response_data[endpoint] = {
                'justified_checkpoint': fork_data.justified_checkpoint,
                'finalized_checkpoint': fork_data.finalized_checkpoint,
                'head_root': fork_data.head_root,
                'nodes': [asdict(node) for node in fork_data.nodes],
                'timestamp': fork_data.timestamp
            }
        
        return web.json_response(response_data)
    except Exception as e:
        logger.error(f"API错误: {e}")
        return web.json_response({'error': str(e)}, status=500)

async def health_check(request):
    """健康检查端点"""
    return web.json_response({
        'status': 'healthy',
        'timestamp': time.time(),
        'active_connections': len(collector.websocket_connections),
        'data_sources': len(collector.latest_data)
    })

async def serve_static(request):
    """提供静态文件"""
    filename = request.match_info.get('filename', 'index.html')
    if filename == '' or filename == '/':
        filename = 'index.html'
    
    try:
        with open(f'/app/static/{filename}', 'r', encoding='utf-8') as f:
            content = f.read()
            
        if filename.endswith('.html'):
            content_type = 'text/html'
        elif filename.endswith('.js'):
            content_type = 'application/javascript'
        elif filename.endswith('.css'):
            content_type = 'text/css'
        else:
            content_type = 'text/plain'
            
        return web.Response(text=content, content_type=content_type)
    except FileNotFoundError:
        return web.Response(text='文件未找到', status=404)

async def init_app():
    """初始化应用"""
    app = web.Application()
    
    # 路由配置
    app.router.add_get('/ws', websocket_handler)
    app.router.add_get('/api/fork-choice', api_fork_choice)
    app.router.add_get('/health', health_check)
    app.router.add_get('/', serve_static)
    app.router.add_get('/{filename:.*}', serve_static)
    
    return app

async def main():
    """主函数"""
    logger.info("启动区块树可视化服务器...")
    
    # 启动数据收集任务
    collection_task = asyncio.create_task(collector.start_collection_loop())
    
    # 创建web应用
    app = await init_app()
    
    # 启动web服务器
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '0.0.0.0', 8000)
    await site.start()
    
    logger.info("服务器已启动在 http://0.0.0.0:8000")
    
    try:
        await collection_task
    except KeyboardInterrupt:
        logger.info("收到中断信号，正在关闭...")
    finally:
        await runner.cleanup()

if __name__ == '__main__':
    asyncio.run(main())
