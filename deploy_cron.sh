#!/bin/bash
# 用法: ./deploy_cron.sh <服务器|序号1-5> <版本号> [动作]
# 示例: ./deploy_cron.sh ali1 vX.Y.Z
# 在ali3
set -euo pipefail

# 记录开始时间
start_time=$(date +%s)
echo "========================================"
echo "开始部署时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================"

server="ali3"
version="$2"
action="${3:-deploy}"

"$(dirname "$0")/deploy.sh" "$server" "$version" "$action" docker-compose.fayon-cron.yaml

# 记录结束时间并计算执行时间
end_time=$(date +%s)
exec_time=$((end_time - start_time))

# 格式化执行时间
if [ $exec_time -ge 3600 ]; then
    hours=$((exec_time / 3600))
    minutes=$(((exec_time % 3600) / 60))
    seconds=$((exec_time % 60))
    time_str="${hours}小时${minutes}分钟${seconds}秒"
elif [ $exec_time -ge 60 ]; then
    minutes=$((exec_time / 60))
    seconds=$((exec_time % 60))
    time_str="${minutes}分钟${seconds}秒"
else
    time_str="${exec_time}秒"
fi

echo "========================================"
echo "部署完成时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo "总执行时间: ${time_str}"
echo "========================================"
