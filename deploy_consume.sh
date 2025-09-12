#!/bin/bash
# 用法: ./deploy_consume.sh <服务器|序号1-5> <版本号> [动作]
# 示例: ./deploy_consume.sh ali1 vX.Y.Z
# 在ali2
set -euo pipefail

server="$1"
version="$2"
action="${3:-deploy}"

"$(dirname "$0")/deploy.sh" "$server" "$version" "$action" docker-compose.fayon-consume.yaml
