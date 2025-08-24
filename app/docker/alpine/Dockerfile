FROM crpi-dpwp83ztynfc9y23.cn-hangzhou.personal.cr.aliyuncs.com/fayon/alpine:3.18

# 设置中国上海时区
ENV TZ=Asia/Shanghai

# 配置国内镜像源（阿里云）
RUN echo "https://mirrors.aliyun.com/alpine/v3.18/main/" > /etc/apk/repositories && \
    echo "https://mirrors.aliyun.com/alpine/v3.18/community/" >> /etc/apk/repositories && \
    # 更新并确保tzdata已安装
    apk update && \
    apk add --no-cache tzdata && \
    # 配置上海时区
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone && \
    # 清理缓存
    rm -rf /var/cache/apk/*

# 验证时区配置
RUN echo "=== 时区验证 ===" && \
    echo "时区: $(cat /etc/timezone)" && \
    echo "当前时间: $(date)" && \
    echo "时区文件: $(readlink -f /etc/localtime)" && \
    echo "================"

CMD ["/bin/sh"]