#!/bin/bash

# 设置语言环境避免警告
export LANG=C 2>/dev/null
export LC_ALL=C 2>/dev/null
#  ./deploy.sh ali1 v0285999 deploy docker-compose.fayon-app.yaml

# 日志与开关
VERBOSE=${VERBOSE:-0}
log() { echo "$@"; }
info() { printf "\033[1;34mℹ️  %s\033[0m\n" "$*"; }
success() { printf "\033[1;32m✅ %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m⚠️  %s\033[0m\n" "$*"; }
error() { printf "\033[1;31m❌ %s\033[0m\n" "$*"; }
debug() { [ "$VERBOSE" = "1" ] && printf "\033[2mDEBUG: %s\033[0m\n" "$*"; }

RAW_SERVER="$1"
VERSION="$2"
ACTION="${3:-deploy}"  # 默认为部署
COMPOSE_FILTER="$4"  # 必填: 指定compose文件名，逗号分隔

# 文件路径
COMPOSE_DIR="app/deploy/server"
VERSION_FILE="app/deploy/server/deploy-versions.log"
SERVICES_CONF="$COMPOSE_DIR/services.conf"

# SSH/SCP 稳健参数，降低网络抖动影响
SSH_OPTS="-o ConnectTimeout=5 -o ServerAliveInterval=30 -o ServerAliveCountMax=1 -o IPQoS=none -o ConnectionAttempts=1 -o GSSAPIAuthentication=no -C"
SCP_OPTS="-o ConnectTimeout=5 -o ServerAliveInterval=30 -o ServerAliveCountMax=1 -o IPQoS=none -o ConnectionAttempts=1 -O -o GSSAPIAuthentication=no -C"

SERVICES="fayon-app fayon-cron fayon-consume fayon-parseip fayon-greeter"

# 从 services.conf 加载服务列表（如存在）
load_services_from_conf() {
    if [ -f "$SERVICES_CONF" ]; then
        local list=$(grep -v '^#' "$SERVICES_CONF" | awk -F':' '/:/{print $1}' | xargs)
        if [ -n "$list" ]; then
            SERVICES="$SERVICES $list"
        fi
    fi
}

load_services_from_conf

# 服务到偏移量的映射
get_service_offset() {
    local name="$1"
    # 优先从 services.conf 中读取
    if [ -f "$SERVICES_CONF" ]; then
        local conf_val=$(grep -v '^#' "$SERVICES_CONF" | awk -F':' -v svc="$name" '$1==svc{print $2}' | xargs)
        if [ -n "$conf_val" ]; then
            echo "$conf_val"
            return
        fi
    fi
    # 回退默认映射
    case "$name" in
        "fayon-app") echo 0 ;;
        "fayon-cron") echo 1 ;;
        "fayon-consume") echo 2 ;;
        "fayon-parseip") echo 3 ;;
        "fayon-greeter") echo 4 ;;
        *) echo 0 ;;
    esac
}


# 标准化服务器参数（支持 1-5 映射）
normalize_server() {
    local arg="$1"
    case "$arg" in
        1|ali1) echo "ali1" ;;
        2|ali2) echo "ali2" ;;
        3|ali3) echo "ali3" ;;
        4|ali4) echo "ali4" ;;
        5|ali5) echo "ali5" ;;
        *) echo "$arg" ;;
    esac
}


# 显示帮助
show_help() {
    echo "使用方法:"
    echo "  $0 <服务器|序号1-5> [版本号] [动作] [compose文件]"
    echo "  动作: deploy (默认), rollback, current, history, backup, backups, restore"
    echo "  compose文件: 必填，逗号分隔多个，如 docker-compose.fayon-app.yaml,docker-compose.fayon-rpc.yaml"
    echo ""
    echo "示例:"
    echo "  $0 ali1 v1.2.3 deploy docker-compose.fayon-app.yaml            # 仅部署 fayon-app"
    echo "  $0 1 v1.2.3 deploy docker-compose.fayon-app.yaml,docker-compose.fayon-rpc.yaml  # 多个compose"
    echo "  $0 ali1 rollback                # 回退到上一个版本"
    echo "  $0 ali1 v1.0.0 rollback         # 回退到指定版本"
    echo "  $0 ali1 current                 # 查看当前版本"
    echo "  $0 ali1 history                 # 查看版本历史"
    echo "  $0 ali1 backup                  # 备份当前配置"
    echo ""
    echo "服务器HOST_NODE分配: 使用服务名作为值"
}

# 检查参数
if [ $# -lt 1 ] || [ "$1" = "help" ]; then
    show_help
    exit 1
fi

SERVER=$(normalize_server "$RAW_SERVER")

# 在服务器上备份当前配置（支持多compose文件）
backup_server_config() {
    local server="$1"
    local version="$2"
    local backup_dir="/root/server/backups"
    local timestamp=$(date '+%Y%m%d-%H%M%S')
    local backup_file="$backup_dir/docker-compose-backup-$timestamp-$version.tar.gz"

    echo "�� 备份当前配置..."
    ssh $SSH_OPTS "$server" "mkdir -p $backup_dir"
    ssh $SSH_OPTS "$server" "cd /root/server && tar -czf $backup_file --warning=no-file-changed --ignore-failed-read *.yaml 2>/dev/null || true"
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

# 获取当前版本（扫描所有 compose yaml）
get_current_version() {
    local server="$1"
    ssh $SSH_OPTS "$server" "grep -ho 'image:.*:[^[:space:]]*' /root/server/*.yaml 2>/dev/null | head -1 | awk -F: '{print $NF}'"
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
    ssh $SSH_OPTS "$server" "ls -la /root/server/backups/docker-compose-backup-*.tar.gz 2>/dev/null | tail -5" || echo "暂无备份文件"
}

# 为每个服务更新HOST_NODE（按服务名赋值）
update_host_nodes() {
    local temp_dir="$1"
    local server="$2"

    echo "📊 HOST_NODE分配(服务名):"

    for service in $SERVICES; do
        local host_node_value="$service"
        for file in "$temp_dir"/*.yaml; do
            [ -f "$file" ] || continue
            update_service_host_node "$file" "$service" "$host_node_value"
        done
    done
}

# 更新单个服务的HOST_NODE（修复版）
update_service_host_node() {
    local temp_file="$1"
    local service_name="$2"
    local host_node_value="$3"

    # 针对不同的服务使用不同的容器名匹配
    local container_name="$service_name"
    if [ "$service_name" = "fayon-cron" ]; then
        container_name="fayon-cmd"  # fayon-cron服务的容器名是fayon-cmd
    fi

    # 如该compose中不存在对应容器，则跳过
    if ! grep -q "container_name: $container_name" "$temp_file"; then
        return 0
    fi

    echo "调试: 更新服务 $service_name 的 HOST_NODE 为 $host_node_value"

    # 使用sed更新指定服务的HOST_NODE
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        sed -i "" "/container_name: $container_name/,/volumes:/s/HOST_NODE=[^[:space:]]*/HOST_NODE=$host_node_value/g" "$temp_file"
        # 额外检查并修复可能的环境变量格式问题
        sed -i "" "/container_name: $container_name/,/volumes:/s/- HOST_NODE=[^[:space:]]*/- HOST_NODE=$host_node_value/g" "$temp_file"
    else
        # Linux
        sed -i "/container_name: $container_name/,/volumes:/s/HOST_NODE=[^[:space:]]*/HOST_NODE=$host_node_value/g" "$temp_file"
        sed -i "/container_name: $container_name/,/volumes:/s/- HOST_NODE=[^[:space:]]*/- HOST_NODE=$host_node_value/g" "$temp_file"
    fi

    # 验证修改是否成功
    local actual_value=$(grep -A 10 "container_name: $container_name" "$temp_file" | grep "HOST_NODE=" | head -1 | cut -d= -f2)
    if [ "$actual_value" = "$host_node_value" ]; then
        echo "✅ $service_name: HOST_NODE=$host_node_value"
    else
        echo "❌ $service_name: 修改失败 (期望: $host_node_value, 实际: $actual_value)"
        # 显示相关配置行以便调试
        echo "调试信息:"
        grep -A 5 -B 5 "container_name: $container_name" "$temp_file"
    fi
}

# 部署版本（多 compose 文件）
deploy_version() {
    local server="$1"
    local version="$2"

    start_ts=$(date +%s)
    info "部署到: $server"
    info "版本号: $version"

    # 检查目录是否存在
    if [ ! -d "$COMPOSE_DIR" ]; then
        echo "❌ 错误: 目录不存在: $COMPOSE_DIR"
        return 1
    fi

    # 备份服务器当前配置
    current_version=$(get_current_version "$server")
    if [ -n "$current_version" ]; then
        backup_server_config "$server" "$current_version"
    fi

    # 在临时目录准备所有compose文件（仅限本地存在的服务对应文件）
    TEMP_DIR="/tmp/compose-$server-$$"
    mkdir -p "$TEMP_DIR"

    # 收集本地 compose 文件：
    # 1) 独立服务文件 docker-compose.<service>.yaml
    # 2) RPC 文件 docker-compose.fayon-rpc.yaml（如存在）
    local compose_files=()

    # 必须指定 compose 文件过滤
    if [ -z "$COMPOSE_FILTER" ]; then
        error "请在第4个参数提供compose文件名，支持逗号分隔"
        return 1
    fi

    IFS=',' read -r -a filters <<< "$COMPOSE_FILTER"
    for f in "${filters[@]}"; do
        # 仅接受 docker-compose.*.yaml
        if [[ "$f" == docker-compose.*.yaml ]]; then
            if [ -f "$COMPOSE_DIR/$f" ]; then
                compose_files+=("$COMPOSE_DIR/$f")
            else
                warn "未找到本地文件: $COMPOSE_DIR/$f"
            fi
        else
            warn "忽略非法文件名: $f (需形如 docker-compose.<name>.yaml)"
        fi
    done

    if [ ${#compose_files[@]} -eq 0 ]; then
        error "未找到任何 compose 文件"
        return 1
    fi

    info "将部署以下文件:"; for f in "${compose_files[@]}"; do log "  - $(basename "$f")"; done

    # 复制到临时目录并替换镜像版本
    for file in "${compose_files[@]}"; do
        local base=$(basename "$file")
        sed "s|image: crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/fayon:[^[:space:]]*|image: crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/fayon:$version|g" "$file" > "$TEMP_DIR/$base"
    done

    # 更新HOST_NODE
    update_host_nodes "$TEMP_DIR" "$server"

    # 同步到服务器
    info "复制文件到服务器..."
    # 简单重试机制，最多重试3次，间隔3秒
    {
        try=1
        while true; do
            scp $SCP_OPTS "$TEMP_DIR"/*.yaml "$server:/root/server/" && break
            if [ $try -ge 3 ]; then
                error "scp 失败（已重试 $try 次）"
                break
            fi
            warn "scp 超时/失败，$try 次重试后继续..."
            try=$((try+1))
            sleep 3
        done
    }

    info "启动服务..."
    # 逐个 compose 文件启动并记录结果
    local results=""
    for file in "$TEMP_DIR"/*.yaml; do
        local base=$(basename "$file")
        local out
        {
            try=1
            success_flag=0
            while true; do
                out=$(ssh $SSH_OPTS "$server" "cd /root/server && docker compose -f $base up -d 2>&1") && success_flag=1 && break
                if [ $try -ge 3 ]; then
                    break
                fi
                warn "远端 docker compose 执行失败/超时，$try 次重试后继续..."
                try=$((try+1))
                sleep 3
            done
        }
        if [ "$success_flag" = "1" ]; then
            success "$base 部署成功"
            debug "$out"
            results+="ok:$base\n"
        else
            error "$base 部署失败"
            log "$out"
            results+="fail:$base\n"
        fi
    done

    # 记录版本
    record_version "$server" "$version" "deploy"

    rm -rf "$TEMP_DIR"

    end_ts=$(date +%s)
    duration=$((end_ts - start_ts))
    info "部署完成，耗时 ${duration}s"
    info "结果概要:"
    printf "%b" "$results"
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
    ssh $SSH_OPTS "$server" "cd /root/server && rm -f *.yaml && tar -xzf /root/server/backups/$backup_file && docker compose ls >/dev/null 2>&1; if [ $? -eq 0 ]; then for f in *.yaml; do docker compose -f \\$f up -d; done; else docker-compose up -d; fi"
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