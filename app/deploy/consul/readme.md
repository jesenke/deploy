# 一键构建Consul


## 快速开始

### 1. 推送配置

```bash
将配置推送到对应服务器
rsync -avz go/src/fayon/deploy/consul/server/ ali1:~/consul/
rsync -avz go/src/fayon/deploy/consul/server2/ ali2:~/consul/
rsync -avz go/src/fayon/deploy/consul/server3/ ali3:~/consul/
```

### 2. 构建docker容器配置数据、日志

```bash
cd consul && mkdir -p  data logs
chmod 777 logs
```

### 2. 运行容器
```cgo
docker compose up -d
```

### 3. 查看集群节点
```cgo
用任意节点容器查询集群成员
docker exec consul-server1 consul members

[root@iZuf62218gqm4ff0nv8axbZ logs]# docker exec consul-server1 consul members
Node     Address              Status  Type    Build   Protocol  DC   Partition  Segment
server1  172.17.178.197:8301  alive   server  1.17.0  2         dc1  default    <all>
server2  172.17.178.196:8301  alive   server  1.17.0  2         dc1  default    <all>
server3  172.17.178.195:8301  alive   server  1.17.0  2         dc1  default    <all>
```


```cgo
用任意节点容器查询集群leader
docker exec consul-server1 consul operator raft list-peers

Node     ID                                    Address              State     Voter  RaftProtocol  Commit Index  Trails Leader By
server1  3af9a31f-5313-07ca-5c53-079deb9386e3  172.17.178.197:8300  follower  true   3             91            0 commits
server2  92924082-0302-7ae8-2ed7-2b6d65510eba  172.17.178.196:8300  leader    true   3             91            -
server3  e8566342-4c0f-7a53-54c9-c07c4bc959dd  172.17.178.195:8300  follower  true   3             91            0 commits
```
