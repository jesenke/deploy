#!/bin/bash

# 设置语言环境避免警告
export LANG=C 2>/dev/null
export LC_ALL=C 2>/dev/null

SERVER="$1"
VERSION="$2"
ACTION="${3:-deploy}"  # 默认为部署

# 文件路径
COMPOSE_FILE="app/deploy/server/docker-compose.yaml"
VERSION_FILE="app/deploy/server/deploy-versions.log"

# 显示帮助
show_help() {
    echo "使用方法:"
    echo "  $0 <服务器> [版本号] [动作]"
    echo "  动作: deploy (默认), rollback, current, history, backup"
    echo ""
    echo "示例:"
    echo "  $0 ali1 v1.2.3          # 部署 v1.2.3 到 ali1"
    echo "  $0 ali1 v1.2.3 deploy   # 同上"
    echo "  $0 ali1 rollback        # 回退到上一个版本"
    echo "  $0 ali1 v1.0.0 rollback # 回退到指定版本"
    echo "  $0 ali1 current         # 查看当前版本"
    echo "  $0 ali1 history         # 查看版本历史"
    echo "  $0 ali1 backup          # 备份当前配置"
}

# 检查参数
if [ $# -lt 1 ] || [ "$1" = "help" ]; then
    show_help
    exit 1
fi

# 在服务器上备份当前配置
backup_server_config() {
    local server="$1"
    local version="$2"
    local backup_dir="/root/server/backups"
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_file="$backup_dir/docker-compose-backup-$timestamp-$version.yaml"

    echo "📦 备份当前配置..."
    ssh "$server" "mkdir -p $backup_dir && cp /root/server/docker-compose.yaml $backup_file"
    echo "✅ 备份完成: $backup_file"
}

# 记录版本历史
record_version() {
    local server="$1"
    local version="$2"
    local action="$3"
    mkdir -p "$(dirname "$VERSION_FILE")"
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $server | $version | $action" >> "$VERSION_FILE"
}

# 获取当前版本
get_current_version() {
    local server="$1"
    ssh "$server" "grep -o 'image:.*:[^[:space:]]*' /root/server/docker-compose.yaml | head -1 | cut -d: -f3" 2>/dev/null
}

# 获取上一个版本
get_previous_version() {
    local server="$1"
    if [ -f "$VERSION_FILE" ]; then
        if command -v tac >/dev/null 2>&1; then
            tac "$VERSION_FILE" | grep "| $server |" | head -1 | awk -F'|' '{print $3}' | tr -d ' '
        else
            tail -r "$VERSION_FILE" 2>/dev/null | grep "| $server |" | head -1 | awk -F'|' '{print $3}' | tr -d ' '
        fi
    fi
}

# 获取备份文件列表
get_backup_files() {
    local server="$1"
    ssh "$server" "ls -la /root/server/backups/docker-compose-backup-*.yaml 2>/dev/null | tail -5" || echo "暂无备份文件"
}

# 部署版本
deploy_version() {
    local server="$1"
    local version="$2"

    echo "🚀 部署到: $server"
    echo "📦 版本号: $version"

    # 检查文件是否存在
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "❌ 错误: docker-compose.yaml 文件不存在: $COMPOSE_FILE"
        return 1
    fi

    # 备份服务器当前配置
    current_version=$(get_current_version "$server")
    if [ -n "$current_version" ]; then
        backup_server_config "$server" "$current_version"
    fi

    # 创建临时文件并更新版本号
    TEMP_FILE="/tmp/docker-compose-$server.yaml"
    sed "s|image: crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/fayon:[^[:space:]]*|image: crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/fayon:$version|g" \
        "$COMPOSE_FILE" > "$TEMP_FILE"

    # 部署
    echo "📤 复制文件到服务器..."
    scp "$TEMP_FILE" "$server:/root/server/docker-compose.yaml"

    echo "🚀 启动服务..."
    ssh "$server" "cd /root/server && docker compose up -d"

    # 记录版本
    record_version "$server" "$version" "deploy"

    rm -f "$TEMP_FILE"
    echo "✅ 部署完成!"
}

# 回退版本
rollback_version() {
    local server="$1"
    local version="$2"

    # 如果没有指定版本，使用上一个版本
    if [ -z "$version" ]; then
        version=$(get_previous_version "$server")
        if [ -z "$version" ]; then
            echo "❌ 找不到上一个版本"
            return 1
        fi
        echo "↩️  回退到上一个版本: $version"
    else
        echo "↩️  回退到指定版本: $version"
    fi

    # 备份当前配置
    current_version=$(get_current_version "$server")
    if [ -n "$current_version" ]; then
        backup_server_config "$server" "$current_version"
    fi

    # 部署回退版本
    deploy_version "$server" "$version"
    record_version "$server" "$version" "rollback"
}

# 查看当前版本
show_current_version() {
    local server="$1"
    local current_version=$(get_current_version "$server")

    if [ -z "$current_version" ]; then
        echo "❌ 无法获取 $server 的当前版本"
    else
        echo "📋 $server 当前版本: $current_version"
    fi
}

# 查看版本历史
show_version_history() {
    local server="$1"

    if [ ! -f "$VERSION_FILE" ]; then
        echo "📝 暂无版本历史记录"
        return
    fi

    echo "📝 $server 版本历史:"
    if grep "| $server |" "$VERSION_FILE" >/dev/null 2>&1; then
        grep "| $server |" "$VERSION_FILE" | tail -5
    else
        echo "  暂无记录"
    fi
}

# 查看备份文件
show_backups() {
    local server="$1"
    echo "📦 $server 备份文件:"
    get_backup_files "$server"
}

# 从备份恢复
restore_from_backup() {
    local server="$1"
    local backup_file="$2"

    if [ -z "$backup_file" ]; then
        echo "❌ 请指定备份文件名"
        return 1
    fi

    echo "🔄 从备份恢复: $backup_file"
    ssh "$server" "cp /root/server/backups/$backup_file /root/server/docker-compose.yaml && cd /root/server && docker compose up -d"
    echo "✅ 恢复完成"
}

# 主逻辑
case "$ACTION" in
    "deploy")
        if [ -z "$VERSION" ]; then
            echo "❌ 请指定要部署的版本号"
            show_help
            exit 1
        fi
        deploy_version "$SERVER" "$VERSION"
        ;;
    "rollback")
        rollback_version "$SERVER" "$VERSION"
        ;;
    "current")
        show_current_version "$SERVER"
        ;;
    "history")
        show_version_history "$SERVER"
        ;;
    "backup")
        current_version=$(get_current_version "$SERVER")
        if [ -n "$current_version" ]; then
            backup_server_config "$SERVER" "$current_version"
        else
            echo "❌ 无法获取当前版本进行备份"
        fi
        ;;
    "backups")
        show_backups "$SERVER"
        ;;
    "restore")
        restore_from_backup "$SERVER" "$VERSION"
        ;;
    *)
        echo "❌ 未知动作: $ACTION"
        show_help
        exit 1
        ;;
esac