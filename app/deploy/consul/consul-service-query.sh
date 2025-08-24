#!/bin/bash

# Consul 服务查询脚本
# 用于查询 Consul 中注册的服务信息

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Consul 配置
CONSUL_HOST="${CONSUL_HOST:-127.0.0.1}"
CONSUL_PORT="${CONSUL_PORT:-8500}"
CONSUL_API="http://${CONSUL_HOST}:${CONSUL_PORT}/v1"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# 检查 Consul 连接
check_consul_connection() {
    log_info "检查 Consul 连接..."
    
    if curl -s "${CONSUL_API}/status/leader" >/dev/null 2>&1; then
        log_success "Consul 连接正常"
        return 0
    else
        log_error "无法连接到 Consul (${CONSUL_API})"
        log_info "请检查："
        log_info "1. Consul 服务是否正在运行"
        log_info "2. 端口 ${CONSUL_PORT} 是否开放"
        log_info "3. 网络连接是否正常"
        return 1
    fi
}

# 获取 Consul 集群信息
get_cluster_info() {
    log_header "集群信息"
    
    # 获取 Leader 信息
    LEADER=$(curl -s "${CONSUL_API}/status/leader" | tr -d '"')
    if [ "$LEADER" != "null" ]; then
        echo -e "${CYAN}Leader:${NC} $LEADER"
    else
        echo -e "${YELLOW}Leader:${NC} 未选举"
    fi
    
    # 获取集群成员
    echo -e "\n${CYAN}集群成员:${NC}"
    curl -s "${CONSUL_API}/agent/members" | jq -r '.[] | "  \(.Name): \(.Addr):\(.Port) (\(.Status))"' 2>/dev/null || echo "  无法获取成员信息"
    
    # 获取数据中心信息
    DC=$(curl -s "${CONSUL_API}/agent/self" | jq -r '.Config.Datacenter' 2>/dev/null || echo "未知")
    echo -e "\n${CYAN}数据中心:${NC} $DC"
}

# 获取所有服务列表
get_services() {
    log_header "已注册服务"
    
    SERVICES=$(curl -s "${CONSUL_API}/catalog/services" | jq -r 'keys[]' 2>/dev/null)
    
    if [ -z "$SERVICES" ]; then
        echo "暂无注册的服务"
        return
    fi
    
    echo "服务列表："
    echo "$SERVICES" | while read -r service; do
        if [ -n "$service" ]; then
            echo -e "  ${GREEN}•${NC} $service"
        fi
    done
}

# 获取特定服务的详细信息
get_service_detail() {
    local service_name="$1"
    
    if [ -z "$service_name" ]; then
        log_error "请提供服务名称"
        return 1
    fi
    
    log_header "服务详情: $service_name"
    
    # 获取服务实例
    INSTANCES=$(curl -s "${CONSUL_API}/catalog/service/$service_name" 2>/dev/null)
    
    if [ "$(echo "$INSTANCES" | jq 'length')" -eq 0 ]; then
        log_warning "服务 '$service_name' 未找到或没有实例"
        return 1
    fi
    
    echo "$INSTANCES" | jq -r '.[] | "实例: \(.ServiceName)@\(.Node)\n  地址: \(.ServiceAddress):\(.ServicePort)\n  状态: \(.Checks[] | select(.ServiceName == "'$service_name'") | .Status)\n"' 2>/dev/null || echo "无法获取服务详情"
}

# 获取所有节点信息
get_nodes() {
    log_header "节点信息"
    
    NODES=$(curl -s "${CONSUL_API}/catalog/nodes" 2>/dev/null)
    
    if [ "$(echo "$NODES" | jq 'length')" -eq 0 ]; then
        echo "暂无节点信息"
        return
    fi
    
    echo "$NODES" | jq -r '.[] | "节点: \(.Node)\n  地址: \(.Address)\n  数据中心: \(.Datacenter)\n"' 2>/dev/null || echo "无法获取节点信息"
}

# 获取健康检查状态
get_health_checks() {
    log_header "健康检查状态"
    
    CHECKS=$(curl -s "${CONSUL_API}/agent/checks" 2>/dev/null)
    
    if [ "$(echo "$CHECKS" | jq 'length')" -eq 0 ]; then
        echo "暂无健康检查"
        return
    fi
    
    echo "$CHECKS" | jq -r 'to_entries[] | "检查: \(.key)\n  状态: \(.value.Status)\n  输出: \(.value.Output // "无")\n"' 2>/dev/null || echo "无法获取健康检查信息"
}

# 获取 KV 存储信息
get_kv_info() {
    log_header "KV 存储信息"
    
    # 获取所有 KV 键
    KEYS=$(curl -s "${CONSUL_API}/kv/?keys" 2>/dev/null)
    
    if [ "$(echo "$KEYS" | jq 'length')" -eq 0 ]; then
        echo "暂无 KV 数据"
        return
    fi
    
    echo "KV 键列表："
    echo "$KEYS" | jq -r '.[]' 2>/dev/null | while read -r key; do
        if [ -n "$key" ]; then
            echo -e "  ${GREEN}•${NC} $key"
        fi
    done
}

# 获取 ACL 信息
get_acl_info() {
    log_header "ACL 信息"
    
    # 检查 ACL 是否启用
    ACL_ENABLED=$(curl -s "${CONSUL_API}/agent/self" | jq -r '.Config.ACL.Enabled' 2>/dev/null || echo "false")
    
    if [ "$ACL_ENABLED" = "true" ]; then
        log_info "ACL 已启用"
        
        # 获取 ACL 令牌信息
        TOKENS=$(curl -s "${CONSUL_API}/acl/tokens" 2>/dev/null)
        if [ "$(echo "$TOKENS" | jq 'length')" -gt 0 ]; then
            echo "ACL 令牌："
            echo "$TOKENS" | jq -r '.[] | "  \(.AccessorID): \(.Description // "无描述")"' 2>/dev/null || echo "无法获取令牌信息"
        fi
    else
        log_info "ACL 未启用"
    fi
}

# 获取统计信息
get_stats() {
    log_header "统计信息"
    
    # 获取代理统计信息
    STATS=$(curl -s "${CONSUL_API}/agent/metrics" 2>/dev/null)
    
    if [ -n "$STATS" ]; then
        echo "运行时统计："
        echo "$STATS" | jq -r '.Gauges[] | "  \(.Name): \(.Value)"' 2>/dev/null | head -10 || echo "无法获取统计信息"
    else
        echo "无法获取统计信息"
    fi
}

# 交互式服务查询
interactive_query() {
    log_header "交互式查询"
    
    # 获取所有服务
    SERVICES=$(curl -s "${CONSUL_API}/catalog/services" | jq -r 'keys[]' 2>/dev/null)
    
    if [ -z "$SERVICES" ]; then
        echo "暂无注册的服务"
        return
    fi
    
    echo "可用服务："
    echo "$SERVICES" | nl
    
    echo ""
    read -p "请输入服务编号查看详情 (或按 Enter 跳过): " choice
    
    if [ -n "$choice" ]; then
        SELECTED_SERVICE=$(echo "$SERVICES" | sed -n "${choice}p")
        if [ -n "$SELECTED_SERVICE" ]; then
            get_service_detail "$SELECTED_SERVICE"
        fi
    fi
}

# 导出服务信息到文件
export_services() {
    local output_file="${1:-consul-services-$(date +%Y%m%d-%H%M%S).json}"
    
    log_info "导出服务信息到 $output_file"
    
    # 获取所有服务信息
    SERVICES_DATA=$(curl -s "${CONSUL_API}/catalog/services")
    NODES_DATA=$(curl -s "${CONSUL_API}/catalog/nodes")
    CHECKS_DATA=$(curl -s "${CONSUL_API}/agent/checks")
    
    # 组合数据
    cat > "$output_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "consul_host": "${CONSUL_HOST}:${CONSUL_PORT}",
  "services": $SERVICES_DATA,
  "nodes": $NODES_DATA,
  "checks": $CHECKS_DATA
}
EOF
    
    log_success "服务信息已导出到 $output_file"
}

# 显示帮助信息
show_help() {
    echo "Consul 服务查询脚本"
    echo ""
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  all             显示所有信息"
    echo "  services        显示服务列表"
    echo "  service <name>  显示特定服务详情"
    echo "  nodes           显示节点信息"
    echo "  health          显示健康检查"
    echo "  kv              显示 KV 存储信息"
    echo "  acl             显示 ACL 信息"
    echo "  stats           显示统计信息"
    echo "  interactive     交互式查询"
    echo "  export [file]   导出服务信息到文件"
    echo "  help            显示此帮助信息"
    echo ""
    echo "环境变量:"
    echo "  CONSUL_HOST      Consul 主机地址 (默认: 127.0.0.1)"
    echo "  CONSUL_PORT      Consul 端口 (默认: 8500)"
    echo ""
    echo "示例:"
    echo "  $0 all"
    echo "  $0 service my-service"
    echo "  $0 export"
    echo "  CONSUL_HOST=192.168.1.100 $0 services"
}

# 主函数
main() {
    case "${1:-all}" in
        all)
            check_consul_connection && {
                get_cluster_info
                get_services
                get_nodes
                get_health_checks
                get_kv_info
                get_acl_info
                get_stats
            }
            ;;
        services)
            check_consul_connection && get_services
            ;;
        service)
            check_consul_connection && get_service_detail "$2"
            ;;
        nodes)
            check_consul_connection && get_nodes
            ;;
        health)
            check_consul_connection && get_health_checks
            ;;
        kv)
            check_consul_connection && get_kv_info
            ;;
        acl)
            check_consul_connection && get_acl_info
            ;;
        stats)
            check_consul_connection && get_stats
            ;;
        interactive)
            check_consul_connection && interactive_query
            ;;
        export)
            check_consul_connection && export_services "$2"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "未知命令: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@" 