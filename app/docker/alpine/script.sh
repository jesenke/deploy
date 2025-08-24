#!/bin/bash
set -e

# 配置变量
REGISTRY="crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon"
IMAGE_NAME="alpine"
TAG="3.18-shanghai"
FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}:${TAG}"

# 支持的平台
PLATFORMS="linux/amd64,linux/arm64"

echo "开始构建多平台镜像: ${FULL_IMAGE}"
echo "支持平台: ${PLATFORMS}"

# 使用 Buildx 构建并推送多平台镜像
docker buildx build \
    --file Dockerfile \
    --platform ${PLATFORMS} \
    --tag ${FULL_IMAGE} \
    --push \
    .

echo "镜像构建并推送完成!"

# 验证镜像
echo -e "\n验证镜像清单:"
docker buildx imagetools inspect ${FULL_IMAGE}

# 测试各个平台
echo -e "\n测试各平台镜像:"
for platform in amd64 arm64; do
    echo "测试平台 linux/${platform}:"
    docker run --rm --platform linux/${platform} ${FULL_IMAGE} sh -c \
        "echo '平台: $(uname -m)'; echo '时区: $(cat /etc/timezone)'; echo '时间: $(date)'"
    echo "---"
done