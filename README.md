<img width="403" height="360" alt="81ae5adf4450cd230bffee7d02fb7731" src="https://github.com/user-attachments/assets/163faa29-89f6-400d-b827-225910a6de12" />
deepseek写的，用nftables管理对外端口，bug未知，测试了开关tcp端口正常，udp没测试，第一次运行请初始化，会只保留22端口防止失联，同时还会阻止ping，选择完全禁用防火墙可开放ping及所有端口，只选只开所有端口不会开放ping，可能还有选项是无用的，会自己设nftables开机自启动，好像是成功的，添加内网连接，使用p2p组网后，可以内网ip连接未对外开放的端口，22端口也可以，对的，关闭外网ssh端口可以这样连接，也不知道安不安全，
本想把一键开关ping搞进去，奈何ai写的总是不能用，有大佬路过可以帮忙看看嘛！改改吗？
markdown
# nftables 防火墙管理脚本

## 一键安装和运行

### 方法1：分步执行（推荐）
```bash
# 下载脚本
curl -fsSL -o nftables.sh https://raw.githubusercontent.com/sunqin0310/nftables/refs/heads/main/nftables.sh

# 添加执行权限
chmod +x nftables.sh

# 运行脚本（需要管理员权限）
sudo bash nftables.sh

### 方法2：单行命令
```bash
curl -fsSL -o nftables.sh https://raw.githubusercontent.com/sunqin0310/nftables/refs/heads/main/nftables.sh && chmod +x nftables.sh && sudo bash nftables.sh

### 方法3：直接执行（不保存文件）
```bash
curl -fsSL https://raw.githubusercontent.com/sunqin0310/nftables/refs/heads/main/nftables.sh | sudo bash
