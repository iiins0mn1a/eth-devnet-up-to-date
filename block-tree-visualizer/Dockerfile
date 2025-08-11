FROM python:3.11-slim

LABEL maintainer="Ethereum Testnet Visualizer"
LABEL description="Block tree visualizer for Ethereum PoS testnet"

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用文件
COPY server.py .
COPY static/ ./static/

# 创建非root用户
RUN useradd -m -u 1000 visualizer && chown -R visualizer:visualizer /app
USER visualizer

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

# 启动命令
CMD ["python", "server.py"]
