#!/bin/bash
# 安装Docker的自动化脚本 for CentOS

# 移除可能存在的问题repo文件
echo "移除旧的docker-ce.repo文件..."
sudo rm -f /etc/yum.repos.d/docker-ce.repo

# 创建新的docker-ce.repo文件
echo "配置阿里云Docker镜像源..."
sudo tee /etc/yum.repos.d/docker-ce.repo <<-'EOF'
[docker-ce-stable]
name=Docker CE Stable - $basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/$releasever/$basearch/stable
enabled=1
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-stable-debuginfo]
name=Docker CE Stable - Debuginfo $basearch
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/$releasever/debug-$basearch/stable
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg

[docker-ce-stable-source]
name=Docker CE Stable - Sources
baseurl=https://mirrors.aliyun.com/docker-ce/linux/centos/$releasever/source/stable
enabled=0
gpgcheck=1
gpgkey=https://mirrors.aliyun.com/docker-ce/linux/centos/gpg
EOF

# 清理并重建yum缓存
echo "清理yum缓存..."
sudo yum clean all
echo "生成新的yum缓存..."
sudo yum makecache fast

# 更新系统并安装Docker
echo "更新系统包..."
sudo yum update -y
echo "安装Docker组件..."
sudo yum install -y docker-ce docker-ce-cli containerd.io

# 启动Docker服务并设置开机自启
echo "启动Docker服务..."
sudo systemctl start docker
echo "设置Docker开机自启..."
sudo systemctl enable docker

# 验证安装结果
echo "验证Docker安装..."
if docker --version &> /dev/null; then
    echo "Docker安装成功！版本信息："
    docker --version
else
    echo "Docker安装失败，请检查错误信息。"
    exit 1
fi
