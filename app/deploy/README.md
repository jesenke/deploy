# Fayon 部署工具

## 构建脚本

### 统一构建脚本 (`build.sh`)

这是推荐的构建脚本，支持多平台构建和推送。

```bash
# 基本用法
./deploy/docker-build-nginx.sh

# 构建并推送到阿里云
./deploy/docker-build-nginx.sh --push

# 构建特定标签
./deploy/docker-build-nginx.sh --tag v1.0.0 --push

# 构建 CentOS 兼容镜像
./deploy/docker-build-nginx.sh --tag centos-compatible --platform linux/amd64 --push

# 仅登录镜像仓库
./deploy/docker-build-nginx.sh --login

# 查看帮助
./deploy/docker-build-nginx.sh --help
```

### 支持的平台

- `linux/amd64` - CentOS, Ubuntu, Debian x86_64
- `linux/arm64` - ARM64 服务器
- `linux/arm/v7` - ARM v7 设备

## 部署脚本

### Gateway 部署 (`deploy-gateway.sh`)

用于部署 Gateway 服务到本地环境。

```bash
# 启动服务
./deploy/deploy-gateway.sh

# 查看状态
./deploy/deploy-gateway.sh --status

# 查看日志
./deploy/deploy-gateway.sh --logs

# 停止服务
./deploy/deploy-gateway.sh --stop
```

### 推送到阿里云 (`push-to-aliyun.sh`)

用于推送镜像到阿里云容器镜像服务。

```bash
# 推送最新镜像
./deploy/push-to-aliyun.sh

# 推送特定标签
./deploy/push-to-aliyun.sh v1.0.0

# 推送特定架构
./deploy/push-to-aliyun.sh latest amd64
```

## Docker Compose 文件

### Gateway 专用部署 (`docker-compose-gateway-only.yml`)

简化的 Docker Compose 文件，只部署 Gateway 服务。

```bash
# 启动服务
docker-compose -f deploy/docker-compose-gateway-only.yml up -d

# 查看状态
docker-compose -f deploy/docker-compose-gateway-only.yml ps

# 查看日志
docker-compose -f deploy/docker-compose-gateway-only.yml logs -f
```

### 完整部署 (`docker-compose-gateway.yml`)

包含所有服务的 Docker Compose 文件（MySQL、Redis、Consul 已注释）。

```bash
# 启动服务
docker-compose -f deploy/docker-compose-gateway.yml up -d
```

## CentOS 部署指南

### 1. 构建 CentOS 兼容镜像

```bash
# 构建 x86_64 镜像
./deploy/docker-build-nginx.sh --tag centos-compatible --platform linux/amd64 --push
```

### 2. 在 CentOS 上部署

```bash
# 拉取镜像
docker pull crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/fayon:centos-compatible

# 运行容器
docker run -d --name fayon-gateway \
  -p 8000:8000 \
  -e CONSUL_HOST=host.docker.internal \
  -e CONSUL_PORT=8500 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=3306 \
  -e DB_NAME=fayon \
  -e DB_USER=fayon \
  -e DB_PASSWORD=123456 \
  -e REDIS_HOST=host.docker.internal \
  -e REDIS_PORT=6379 \
  --add-host host.docker.internal:host-gateway \
  crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/fayon:centos-compatible
```

### 3. 验证部署

```bash
# 健康检查
curl http://localhost:8000/health

# API 文档
curl http://localhost:8000/docs

# Swagger UI
curl http://localhost:8000/swagger-ui.html
```

## 故障排除

### 架构不匹配错误

如果遇到 `exec format error`，说明镜像架构与系统不匹配：

```bash
# 检查镜像架构
docker inspect <镜像名> | grep Architecture

# 重新构建正确架构的镜像
./deploy/docker-build-nginx.sh --platform linux/amd64 --push
```

### 网络连接问题

确保容器可以访问宿主机服务：

```bash
# 检查网络连接
docker exec fayon-gateway ping host.docker.internal

# 检查端口映射
netstat -tlnp | grep 8000
```

### 服务连接问题

检查 MySQL、Redis、Consul 服务是否正常运行：

```bash
# 检查 MySQL
sudo systemctl status mysql

# 检查 Redis
sudo systemctl status redis

# 检查 Consul
docker ps | grep consul
```

## 文档

- [CentOS 部署指南](centos-deployment-guide.md)
- [网络配置说明](network-setup.md)
- [Docker 环境配置](docker_environment_config.md) 