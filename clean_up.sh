#!/bin/bash
LOG_DIR="/root/server/logs"          # 日志目录，请按需修改
DAYS_OLD=5                            # 保留天数，删除此天数前的文件

# 计算截止日期（两种格式：YYYY-MM-DD 和 YYYYMMDD）
CUTOFF_DATE=$(date -d "$DAYS_OLD days ago" +%Y-%m-%d)
CUTOFF_NUM=$(date -d "$DAYS_OLD days ago" +%Y%m%d)

echo "截止日期（含此日及之前将被删除）: $CUTOFF_DATE"

# 检查目录是否存在
if [ ! -d "$LOG_DIR" ]; then
    echo "错误: 目录 $LOG_DIR 不存在"
    exit 1
fi

# 遍历所有 .log 文件
for logfile in "$LOG_DIR"/*.log; do
    # 如果没有匹配的文件，跳过
    [ -e "$logfile" ] || continue

    filename=$(basename "$logfile")
    echo "检查文件: $filename"

    # --- 情况1：纯日期格式 YYYY-MM-DD.log ---
    if [[ $filename =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})\.log$ ]]; then
        file_date="${BASH_REMATCH[1]}"
        echo "  匹配格式1，文件日期: $file_date"
        if [[ "$file_date" < "$CUTOFF_DATE" || "$file_date" == "$CUTOFF_DATE" ]]; then
            echo "  -> 删除 $filename"
            rm -f "$logfile"      # 确认无误后取消注释
            echo "$(date +'%Y-%m-%d %H:%M:%S') - 已删除 $filename" >> /var/log/cleanup.log
        else
            echo "  -> 保留 $filename (日期晚于截止日期)"
        fi
        continue
    fi

    # --- 情况2：带前缀并以8位数字结尾，如 access-20260225.log ---
    if [[ $filename =~ ([0-9]{8})\.log$ ]]; then
        file_date_num="${BASH_REMATCH[1]}"
        # 转换为 YYYY-MM-DD 格式（便于人类阅读和比较）
        file_date="${file_date_num:0:4}-${file_date_num:4:2}-${file_date_num:6:2}"
        echo "  匹配格式2，文件日期: $file_date (数字: $file_date_num)"
        # 可以直接用数字比较，更简单
        if [[ "$file_date_num" -le "$CUTOFF_NUM" ]]; then
            echo "  -> 删除 $filename"
            rm -f "$logfile"
            echo "$(date +'%Y-%m-%d %H:%M:%S') - 已删除 $filename" >> /var/log/cleanup.log
        else
            echo "  -> 保留 $filename (日期晚于截止日期)"
        fi
        continue
    fi

    # --- 其他格式的文件，跳过并提示 ---
    echo "  跳过 $filename (文件名格式不匹配)"
done
