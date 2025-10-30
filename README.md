<img width="403" height="360" alt="81ae5adf4450cd230bffee7d02fb7731" src="https://github.com/user-attachments/assets/163faa29-89f6-400d-b827-225910a6de12" />

deepseek写的，用nftables管理对外端口，bug未知，测试了开关tcp端口正常，udp没测试，第一次运行请初始化，会只保留22端口防止失联，同时还会阻止ping，选择完全禁用防火墙可开放ping及所有端口，只选只开所有端口不会开放ping，可能还有选项是无用的，会自己设nftables开机自启动，好像是成功的，添加内网连接，使用p2p组网后，可以内网ip连接未对外开放的端口，22端口也可以，对的，关闭外网ssh端口可以这样连接，也不知道安不安全，
本想把一键开关ping搞进去，奈何ai写的总是不能用，有大佬路过可以帮忙看看嘛！改改吗？
# 注意
只适合没有安全组没有外部防火墙没有ipv6的vps，只支持ipv4，最好是刚重装系统且没有启动任何防火墙和规则的vps，用docker的有冲突，不要用请勿使用
## 🚀 一键安装和运行

### 方法1：分步执行（推荐安全方式）

#### 步骤1: 下载脚本到当前目录
```bash
curl -fsSL -o nftables.sh https://raw.githubusercontent.com/sunqin0310/nftables/refs/heads/main/nftables.sh
```

#### 步骤2: 给脚本添加执行权限
```bash
chmod +x nftables.sh
```

#### 步骤3: 以管理员权限运行脚本
```bash
sudo bash nftables.sh
```

### 方法2：单行快捷命令
```bash
curl -fsSL -o nftables.sh https://raw.githubusercontent.com/sunqin0310/nftables/refs/heads/main/nftables.sh && chmod +x nftables.sh && sudo bash nftables.sh
```

## 📋 执行步骤说明
下载脚本 - 从GitHub获取最新版本的脚本文件

授权执行 - 给脚本添加执行权限（可选但推荐）

运行管理 - 以管理员权限启动防火墙管理界面

## ⚙️ 系统要求
Linux 操作系统

curl 命令行工具

sudo 权限

nftables（如未安装，脚本会自动安装）

## 🎯 功能特点
可视化 nftables 防火墙管理

支持端口段批量管理

内网访问智能控制

常用服务端口快速配置

实时状态监控显示
