#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # 无颜色

# 显示颜色化输出
print_message() {
    echo -e "${2}${1}${NC}"
}

# 检查输入是否为退出命令
check_exit() {
    if [[ "$1" == "q" ]] || [[ "$1" == "Q" ]]; then
        print_message "已取消操作" "$YELLOW"
        return 0
    fi
    return 1
}

# 检查权限并设置命令前缀
check_privileges() {
    if [ "$EUID" -eq 0 ]; then
        CMD_PREFIX=""
        print_message "当前以 root 权限运行" "$GREEN"
    else
        CMD_PREFIX="sudo"
        print_message "当前以普通用户权限运行，将使用 sudo 执行命令" "$YELLOW"
        
        if ! $CMD_PREFIX -v &> /dev/null; then
            print_message "错误: 需要 root 权限或 sudo 权限来运行此脚本" "$RED"
            exit 1
        fi
    fi
}

# 检查nftables是否安装
check_nftables_installed() {
    if ! command -v nft &> /dev/null; then
        print_message "nftables 未安装，正在安装..." "$YELLOW"
        
        if command -v apt &> /dev/null; then
            $CMD_PREFIX apt update
            $CMD_PREFIX apt install -y nftables
        elif command -v yum &> /dev/null; then
            $CMD_PREFIX yum install -y nftables
        elif command -v dnf &> /dev/null; then
            $CMD_PREFIX dnf install -y nftables
        else
            print_message "错误: 无法确定包管理器，请手动安装nftables" "$RED"
            exit 1
        fi
        
        if [ $? -eq 0 ]; then
            print_message "nftables 安装成功！" "$GREEN"
        else
            print_message "nftables 安装失败，请检查网络连接或权限" "$RED"
            exit 1
        fi
    else
        print_message "nftables 已安装" "$GREEN"
    fi
}

# 执行nft命令
nft_cmd() {
    $CMD_PREFIX nft "$@"
}

# 保存nftables规则并确保重启后生效
save_nftables_rules() {
    print_message "正在保存 nftables 规则..." "$YELLOW"
    
    # 确保配置目录存在
    $CMD_PREFIX mkdir -p /etc/nftables
    
    # 保存当前规则
    nft_cmd list ruleset > /tmp/nftables-current.rules
    
    # 备份旧配置
    if [ -f "/etc/nftables.conf" ]; then
        $CMD_PREFIX cp /etc/nftables.conf /etc/nftables.conf.backup.$(date +%Y%m%d-%H%M%S)
    fi
    
    # 安装到系统配置
    $CMD_PREFIX cp /tmp/nftables-current.rules /etc/nftables.conf
    
    # 确保nftables服务启用并在重启后自动启动
    if command -v systemctl &> /dev/null; then
        # 重新加载systemd配置
        $CMD_PREFIX systemctl daemon-reload 2>/dev/null || true
        
        # 启用nftables服务（开机自启）
        $CMD_PREFIX systemctl enable nftables 2>/dev/null || true
        
        # 启动nftables服务
        $CMD_PREFIX systemctl start nftables 2>/dev/null || true
        
        print_message "nftables 服务已启用并启动" "$GREEN"
    fi
    
    # 对于不使用systemd的系统，创建init脚本
    if [ ! -f "/etc/rc.local" ] && [ ! -d "/etc/systemd" ]; then
        print_message "检测到非systemd系统，创建rc.local规则加载" "$YELLOW"
        echo -e "#!/bin/bash\nnft -f /etc/nftables.conf" | $CMD_PREFIX tee /etc/rc.local > /dev/null
        $CMD_PREFIX chmod +x /etc/rc.local
    fi
    
    print_message "nftables 规则已保存到 /etc/nftables.conf 并确保重启后生效" "$GREEN"
}

# 加载nftables规则
load_nftables_rules() {
    if [ -f "/etc/nftables.conf" ]; then
        print_message "正在从 /etc/nftables.conf 加载规则..." "$YELLOW"
        nft_cmd -f /etc/nftables.conf
        print_message "规则加载完成" "$GREEN"
    else
        print_message "未找到配置文件 /etc/nftables.conf" "$YELLOW"
    fi
}

# 检查nftables服务状态
check_nftables_service() {
    if command -v systemctl &> /dev/null; then
        if systemctl is-active nftables &> /dev/null; then
            echo "active"
        else
            echo "inactive"
        fi
    else
        echo "unknown"
    fi
}

# 检查端口状态
check_port_status() {
    local port=$1
    local protocol=${2:-"tcp"}
    
    if nft_cmd list ruleset | grep -E "tcp dport $port accept|udp dport $port accept" &> /dev/null; then
        echo "开启"
    else
        echo "关闭"
    fi
}

# 显示当前状态
show_current_status() {
    clear
    print_message "=== nftables 防火墙当前状态 ===" "$CYAN"
    echo "----------------------------------------"
    
    # 显示基本状态
    if nft_cmd list ruleset &> /dev/null; then
        print_message "nftables 状态: 已激活" "$GREEN"
        
        # 显示服务状态
        service_status=$(check_nftables_service)
        if [ "$service_status" = "active" ]; then
            print_message "nftables 服务: 运行中" "$GREEN"
        elif [ "$service_status" = "inactive" ]; then
            print_message "nftables 服务: 未运行" "$RED"
        else
            print_message "nftables 服务: 状态未知" "$YELLOW"
        fi
    else
        print_message "nftables 状态: 未配置" "$RED"
        echo "----------------------------------------"
        return
    fi
    
    # 显示常用端口状态
    echo
    print_message "=== 端口状态 ===" "$BLUE"
    local ports=("22" "80" "443")
    for port in "${ports[@]}"; do
        status=$(check_port_status $port)
        color=$([ "$status" = "开启" ] && echo "$GREEN" || echo "$RED")
        symbol=$([ "$status" = "开启" ] && echo "✓" || echo "✗")
        print_message "  $symbol 端口 $port/tcp 状态: $status" "$color"
    done
    
    echo
    echo "----------------------------------------"
}

# 显示监听端口
show_listening_ports() {
    print_message "=== 系统监听端口 ===" "$PURPLE"
    echo
    print_message "TCP 监听端口:" "$BLUE"
    $CMD_PREFIX ss -tlnp | awk 'NR>1 {printf "  %-8s %-20s %-20s\n", $1, $4, $6}' | while read line; do
        print_message "$line" "$YELLOW"
    done
    
    echo
    print_message "UDP 监听端口:" "$BLUE"
    $CMD_PREFIX ss -ulnp | awk 'NR>1 {printf "  %-8s %-20s %-20s\n", $1, $4, $6}' | while read line; do
        print_message "$line" "$YELLOW"
    done
    echo
}

# 初始化nftables防火墙
initialize_nftables() {
    print_message "正在初始化 nftables 防火墙..." "$YELLOW"
    
    # 刷新所有现有规则
    nft_cmd flush ruleset
    
    # 定义防火墙表
    nft_cmd add table inet firewall
    
    # 定义输入链
    nft_cmd add chain inet firewall input '{ type filter hook input priority 0; policy drop; }'
    
    # 定义转发链
    nft_cmd add chain inet firewall forward '{ type filter hook forward priority 0; policy drop; }'
    
    # 定义输出链
    nft_cmd add chain inet firewall output '{ type filter hook output priority 0; policy accept; }'
    
    # 允许本地回环
    nft_cmd add rule inet firewall input iifname "lo" accept
    nft_cmd add rule inet firewall output oifname "lo" accept
    
    # 允许已建立和相关的连接
    nft_cmd add rule inet firewall input ct state established,related accept
    
    # 允许SSH连接（端口22）
    nft_cmd add rule inet firewall input tcp dport 22 accept
    
    # 保存规则
    save_nftables_rules
    
    print_message "nftables 防火墙初始化完成！" "$GREEN"
    print_message "默认策略: 拒绝所有进入连接，允许所有外出连接" "$GREEN"
    print_message "已开启 22/tcp 端口 (SSH)" "$GREEN"
}

# 开启端口
open_port() {
    local port=$1
    local protocol=${2:-"tcp"}
    
    if [[ "$protocol" == "both" ]]; then
        nft_cmd add rule inet firewall input tcp dport $port accept
        nft_cmd add rule inet firewall input udp dport $port accept
    else
        nft_cmd add rule inet firewall input $protocol dport $port accept
    fi
    
    save_nftables_rules
}

# 关闭端口
close_port() {
    local port=$1
    local protocol=${2:-"tcp"}
    
    # 获取规则的handle
    if [[ "$protocol" == "both" ]]; then
        # 删除TCP规则
        local tcp_handle=$(nft_cmd -a list chain inet firewall input 2>/dev/null | grep "tcp dport $port accept" | grep -o "handle [0-9]*" | head -1 | cut -d' ' -f2)
        if [ -n "$tcp_handle" ]; then
            nft_cmd delete rule inet firewall input handle $tcp_handle
        fi
        
        # 删除UDP规则
        local udp_handle=$(nft_cmd -a list chain inet firewall input 2>/dev/null | grep "udp dport $port accept" | grep -o "handle [0-9]*" | head -1 | cut -d' ' -f2)
        if [ -n "$udp_handle" ]; then
            nft_cmd delete rule inet firewall input handle $udp_handle
        fi
    else
        local rule_handle=$(nft_cmd -a list chain inet firewall input 2>/dev/null | grep "$protocol dport $port accept" | grep -o "handle [0-9]*" | head -1 | cut -d' ' -f2)
        if [ -n "$rule_handle" ]; then
            nft_cmd delete rule inet firewall input handle $rule_handle
        fi
    fi
    
    save_nftables_rules
}

# 开启特定端口交互
open_port_interactive() {
    while true; do
        read -p "请输入要开放的端口号 (例如: 22, 443) (输入 q 退出): " port
        if check_exit "$port"; then
            return
        fi
        
        if [ -n "$port" ]; then
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                print_message "端口号无效，请输入1-65535之间的数字" "$RED"
                continue
            fi
            
            echo "请选择协议:"
            echo "1. TCP"
            echo "2. UDP"
            echo "3. TCP 和 UDP"
            read -p "请选择 [1-3] (输入 q 退出): " protocol_choice
            
            if check_exit "$protocol_choice"; then
                return
            fi
            
            case $protocol_choice in
                1)
                    open_port $port "tcp"
                    print_message "端口 $port/tcp 已开放" "$GREEN"
                    ;;
                2)
                    open_port $port "udp"
                    print_message "端口 $port/udp 已开放" "$GREEN"
                    ;;
                3)
                    open_port $port "both"
                    print_message "端口 $port/tcp 和 $port/udp 已开放" "$GREEN"
                    ;;
                *)
                    print_message "无效选择" "$RED"
                    continue
                    ;;
            esac
            break
        else
            print_message "未输入端口" "$RED"
        fi
    done
}

# 关闭特定端口交互
close_port_interactive() {
    while true; do
        read -p "请输入要关闭的端口号 (例如: 22, 443) (输入 q 退出): " port
        if check_exit "$port"; then
            return
        fi
        
        if [ -n "$port" ]; then
            if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
                print_message "端口号无效，请输入1-65535之间的数字" "$RED"
                continue
            fi
            
            # 检查当前状态
            tcp_status=$(check_port_status $port "tcp")
            udp_status=$(check_port_status $port "udp")
            
            if [ "$tcp_status" = "关闭" ] && [ "$udp_status" = "关闭" ]; then
                print_message "端口 $port 的TCP和UDP协议都已关闭" "$YELLOW"
                read -p "按回车键继续..."
                return
            fi
            
            # SSH端口警告
            if [[ "$port" == "22" ]]; then
                echo
                print_message "警告: 关闭22端口(SSH)可能导致您失去远程连接!" "$RED"
                print_message "只有在您有其他方式访问服务器时才应执行此操作!" "$RED"
                read -p "确认要关闭22端口吗? (输入 'yes' 确认，输入 q 退出): " confirm
                if check_exit "$confirm"; then
                    return
                fi
                if [ "$confirm" != "yes" ]; then
                    print_message "已取消关闭22端口" "$YELLOW"
                    read -p "按回车键继续..."
                    return
                fi
            fi
            
            echo "请选择要关闭的协议:"
            echo "1. TCP $(if [ "$tcp_status" = "关闭" ]; then echo "(已关闭)"; fi)"
            echo "2. UDP $(if [ "$udp_status" = "关闭" ]; then echo "(已关闭)"; fi)"
            echo "3. TCP 和 UDP"
            read -p "请选择 [1-3] (输入 q 退出): " protocol_choice
            
            if check_exit "$protocol_choice"; then
                return
            fi
            
            case $protocol_choice in
                1)
                    if [ "$tcp_status" = "开启" ]; then
                        close_port $port "tcp"
                        print_message "端口 $port/tcp 已关闭" "$GREEN"
                    else
                        print_message "端口 $port/tcp 已经是关闭状态" "$YELLOW"
                    fi
                    ;;
                2)
                    if [ "$udp_status" = "开启" ]; then
                        close_port $port "udp"
                        print_message "端口 $port/udp 已关闭" "$GREEN"
                    else
                        print_message "端口 $port/udp 已经是关闭状态" "$YELLOW"
                    fi
                    ;;
                3)
                    close_port $port "both"
                    print_message "端口 $port/tcp 和 $port/udp 已关闭" "$GREEN"
                    ;;
                *)
                    print_message "无效选择" "$RED"
                    continue
                    ;;
            esac
            break
        else
            print_message "未输入端口" "$RED"
        fi
    done
}

# 显示防火墙端口规则（简化版）
show_firewall_ports() {
    print_message "=== 防火墙端口规则 ===" "$CYAN"
    echo
    
    # 显示TCP端口规则
    print_message "TCP 端口规则:" "$BLUE"
    nft_cmd list chain inet firewall input 2>/dev/null | grep "tcp dport" | while read line; do
        if [[ "$line" == *"accept"* ]]; then
            port=$(echo "$line" | grep -oE "dport [0-9]+" | cut -d' ' -f2)
            print_message "  端口 $port: 允许" "$GREEN"
        fi
    done
    
    # 显示UDP端口规则
    print_message "UDP 端口规则:" "$BLUE"
    nft_cmd list chain inet firewall input 2>/dev/null | grep "udp dport" | while read line; do
        if [[ "$line" == *"accept"* ]]; then
            port=$(echo "$line" | grep -oE "dport [0-9]+" | cut -d' ' -f2)
            print_message "  端口 $port: 允许" "$GREEN"
        fi
    done
    
    echo
}

# 常用端口管理
manage_common_ports() {
    while true; do
        # 获取当前状态
        port_22_status=$(check_port_status 22)
        port_80_status=$(check_port_status 80)
        port_443_status=$(check_port_status 443)
        
        clear
        print_message "=== 常用端口管理 ===" "$PURPLE"
        echo
        print_message "每个端口独立管理，选择后切换状态" "$YELLOW"
        echo
        echo -e "1.  SSH 端口 (22)         [当前状态: $(if [ "$port_22_status" = "开启" ]; then echo -e "${GREEN}${port_22_status}${NC}"; else echo -e "${RED}${port_22_status}${NC}"; fi)]"
        echo -e "2.  HTTP 端口 (80)        [当前状态: $(if [ "$port_80_status" = "开启" ]; then echo -e "${GREEN}${port_80_status}${NC}"; else echo -e "${RED}${port_80_status}${NC}"; fi)]"
        echo -e "3.  HTTPS 端口 (443)      [当前状态: $(if [ "$port_443_status" = "开启" ]; then echo -e "${GREEN}${port_443_status}${NC}"; else echo -e "${RED}${port_443_status}${NC}"; fi)]"
        echo "q.  返回主菜单"
        echo
        
        read -p "请选择操作 [1-3, q] (输入 q 退出): " choice
        
        if check_exit "$choice"; then
            return
        fi
        
        case $choice in
            1)
                if [ "$port_22_status" = "开启" ]; then
                    echo
                    print_message "警告: 关闭22端口(SSH)可能导致您失去远程连接!" "$RED"
                    read -p "确认要关闭22端口吗? (输入 'yes' 确认): " confirm
                    if [ "$confirm" = "yes" ]; then
                        close_port 22 "tcp"
                        print_message "SSH 端口 (22) 已关闭" "$RED"
                    else
                        print_message "已取消关闭22端口" "$YELLOW"
                    fi
                else
                    open_port 22 "tcp"
                    print_message "SSH 端口 (22) 已开启" "$GREEN"
                fi
                ;;
            2)
                if [ "$port_80_status" = "开启" ]; then
                    close_port 80 "tcp"
                    print_message "HTTP 端口 (80) 已关闭" "$RED"
                else
                    open_port 80 "tcp"
                    print_message "HTTP 端口 (80) 已开启" "$GREEN"
                fi
                ;;
            3)
                if [ "$port_443_status" = "开启" ]; then
                    close_port 443 "tcp"
                    print_message "HTTPS 端口 (443) 已关闭" "$RED"
                else
                    open_port 443 "tcp"
                    print_message "HTTPS 端口 (443) 已开启" "$GREEN"
                fi
                ;;
            q)
                return
                ;;
            *)
                print_message "无效选择" "$RED"
                ;;
        esac
        
        sleep 2
    done
}

# nftables基础管理
manage_nftables_basic() {
    while true; do
        clear
        print_message "=== nftables 基础管理 ===" "$PURPLE"
        echo
        echo "1. 初始化 nftables (重置并关闭所有端口，默认开启22端口)"
        echo "2. 保存当前规则"
        echo "3. 重新加载规则"
        echo "4. 重启 nftables 服务"
        echo "5. 完全开放所有端口 (危险)"
        echo "6. 完全禁用防火墙 (接受所有流量)"
        echo "q. 返回主菜单"
        echo
        
        read -p "请选择操作 [1-6, q] (输入 q 退出): " choice
        
        if check_exit "$choice"; then
            return
        fi
        
        case $choice in
            1)
                initialize_nftables
                read -p "按回车键继续..."
                ;;
            2)
                save_nftables_rules
                read -p "按回车键继续..."
                ;;
            3)
                load_nftables_rules
                read -p "按回车键继续..."
                ;;
            4)
                if command -v systemctl &> /dev/null; then
                    print_message "重启 nftables 服务..." "$YELLOW"
                    $CMD_PREFIX systemctl restart nftables
                    print_message "nftables 服务已重启" "$GREEN"
                else
                    print_message "无法重启服务: systemctl 不可用" "$RED"
                fi
                read -p "按回车键继续..."
                ;;
            5)
                print_message "警告: 这将开放所有端口，非常危险!" "$RED"
                read -p "确认要开放所有端口吗? (输入 'DANGER' 确认): " confirm
                if [ "$confirm" = "DANGER" ]; then
                    nft_cmd flush ruleset
                    nft_cmd add table inet firewall
                    nft_cmd add chain inet firewall input '{ type filter hook input priority 0; policy accept; }'
                    nft_cmd add chain inet firewall forward '{ type filter hook forward priority 0; policy accept; }'
                    nft_cmd add chain inet firewall output '{ type filter hook output priority 0; policy accept; }'
                    save_nftables_rules
                    print_message "所有端口已开放" "$RED"
                else
                    print_message "已取消操作" "$YELLOW"
                fi
                read -p "按回车键继续..."
                ;;
            6)
                print_message "警告: 这将完全禁用防火墙!" "$RED"
                read -p "确认要禁用防火墙吗? (输入 'DISABLE' 确认): " confirm
                if [ "$confirm" = "DISABLE" ]; then
                    nft_cmd flush ruleset
                    save_nftables_rules
                    print_message "防火墙已禁用" "$RED"
                else
                    print_message "已取消操作" "$YELLOW"
                fi
                read -p "按回车键继续..."
                ;;
            q)
                return
                ;;
            *)
                print_message "无效选择" "$RED"
                read -p "按回车键继续..."
                ;;
        esac
    done
}

# 显示菜单
show_menu() {
    echo
    print_message "=== nftables 防火墙管理菜单 ===" "$CYAN"
    echo "1.  nftables 基础管理 (初始化/保存/重载)"
    echo "2.  开启特定端口"
    echo "3.  关闭特定端口"
    echo "4.  查看防火墙端口规则"
    echo "5.  查看系统监听端口"
    echo "6.  常用端口管理 (22, 80, 443)"
    echo "q.  退出"
    echo
}

# 主程序
main() {
    # 检查权限
    check_privileges
    
    # 检查nftables是否安装
    check_nftables_installed
    
    # 显示初始状态
    show_current_status
    
    # 检查是否已初始化，如果没有则提示初始化
    if ! nft_cmd list tables &> /dev/null || ! nft_cmd list table inet firewall &> /dev/null; then
        print_message "检测到 nftables 未初始化，建议执行初始化..." "$YELLOW"
        read -p "是否现在初始化防火墙? (y/n, 输入 q 退出): " init_choice
        if [[ "$init_choice" == "y" || "$init_choice" == "Y" ]]; then
            initialize_nftables
            show_current_status
        elif check_exit "$init_choice"; then
            exit 0
        fi
    fi
    
    while true; do
        show_menu
        read -p "请选择操作 [1-6, q] (输入 q 退出): " choice
        
        if check_exit "$choice"; then
            print_message "感谢使用 nftables 防火墙管理脚本！" "$CYAN"
            exit 0
        fi
        
        case $choice in
            1)
                manage_nftables_basic
                show_current_status
                ;;
            2)
                open_port_interactive
                show_current_status
                ;;
            3)
                close_port_interactive
                show_current_status
                ;;
            4)
                clear
                show_firewall_ports
                read -p "按回车键返回主菜单..."
                show_current_status
                ;;
            5)
                clear
                show_listening_ports
                read -p "按回车键返回主菜单..."
                show_current_status
                ;;
            6)
                manage_common_ports
                show_current_status
                ;;
            q)
                print_message "感谢使用 nftables 防火墙管理脚本！" "$CYAN"
                exit 0
                ;;
            *)
                print_message "无效选择，请重新输入" "$RED"
                read -p "按回车键继续..."
                show_current_status
                ;;
        esac
    done
}

# 脚本入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi