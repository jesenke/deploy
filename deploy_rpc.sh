#!/bin/bash
# 用法: ./deploy_rpc.sh <服务器|序号1-5> <版本号> [动作]
# 示例: ./deploy_rpc.sh ali1 vX.Y.Z

set -euo pipefail

server="$1"
version="$2"
action="${3:-deploy}"

"$(dirname "$0")/deploy.sh" "$server" "$version" "$action" docker-compose.fayon-rpc.yaml
