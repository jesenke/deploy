#!/bin/bash

VERSION="$1"

if [ -z "$VERSION" ]; then
    echo "使用方法: $0 <版本号>"
    exit 1
fi

# 服务器和机器序号配置
SERVERS=("ali1:1" "ali2:2" "ali3:3")

for SERVER_INFO in "${SERVERS[@]}"; do
    SERVER=$(echo "$SERVER_INFO" | cut -d: -f1)
    INDEX=$(echo "$SERVER_INFO" | cut -d: -f2)

    echo "正在部署 $SERVER (序号: $INDEX)..."
    ./deploy.sh "$SERVER" "$VERSION" "$INDEX"
    echo "---"
done

echo "🎉 所有服务器部署完成!"