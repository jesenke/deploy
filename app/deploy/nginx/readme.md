# 一键构建Consul


## 快速开始

### 1. 推送配置

```bash
将配置推送到对应服务器
rsync -avz go/src/fayon/deploy/nginx/ ali1:~/nginx/
```

### 2. 生成签名

```bash
cd deploy/nginx/ 
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/server1.key \
  -out ssl/server1.crt \
  -subj "/C=CN/ST=Zhejiang/L=Hangzhou/O=Example/CN=localhost"
  
chmod 600 ssl/server1.key
  
```

### 2. 安装nginx
```cgo
  sudo yum install -y epel-release
  sudo yum install -y nginx
  sudo mkdir -p /etc/nginx/conf.d
  
  sudo systemctl start nginx
  sudo systemctl enable nginx
  
```
