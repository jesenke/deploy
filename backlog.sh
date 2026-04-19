#!/bin/bash

# ===================== 配置区 (根据你的实际情况修改) =====================
# 源日志文件路径
LOG_FILE="/root/server/logs/gateway.stdout.log"
# 备份文件存储目录
BACKUP_DIR="/var/log/backup/gateway"
# 备份文件前缀
BACKUP_PREFIX="gateway.stdout"
# 保留备份文件的天数（超过此天数的备份会被自动删除）
KEEP_DAYS=5
# =========================================================================

# 检查脚本是否以 root 权限运行（可选，根据日志文件权限调整）
if [ "$(id -u)" != "0" ]; then
    echo "错误：建议使用 root 权限运行此脚本，以确保能访问日志文件和写入备份目录"
    exit 1
fi

# 检查源日志文件是否存在
if [ ! -f "$LOG_FILE" ]; then
    echo "错误：源日志文件 $LOG_FILE 不存在！"
    exit 1
fi

# 创建备份目录（如果不存在）
mkdir -p "$BACKUP_DIR"

# 生成备份文件名（包含时间戳，格式：前缀_年-月-日_时-分-秒.log.gz）
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_FILE="${BACKUP_DIR}/${BACKUP_PREFIX}_${TIMESTAMP}.log.gz"

# 备份并压缩日志文件（使用 gzip 压缩节省空间）
# cp 先复制日志文件，避免备份过程中日志写入中断；cat 读取后通过管道传给 gzip 压缩
echo "开始备份日志文件: $LOG_FILE"
cp "$LOG_FILE" "${LOG_FILE}.tmp" && \
cat "${LOG_FILE}.tmp" | gzip > "$BACKUP_FILE" && \
rm -f "${LOG_FILE}.tmp"

# 检查备份是否成功
if [ $? -eq 0 ]; then
    echo "备份成功！备份文件：$BACKUP_FILE"

    # 清空原日志文件（可选，根据需求决定是否清空）
    # > "$LOG_FILE"
    # echo "已清空原日志文件 $LOG_FILE"

    # 清理超过指定天数的旧备份文件
    echo "开始清理 ${KEEP_DAYS} 天前的旧备份文件..."
    find "$BACKUP_DIR" -name "${BACKUP_PREFIX}_*.log.gz" -type f -mtime +${KEEP_DAYS} -delete
    echo "旧备份清理完成"
else
    echo "错误：日志备份失败！"
    rm -f "${LOG_FILE}.tmp" "$BACKUP_FILE"  # 清理临时文件和失败的备份
    exit 1
fi

exit 0