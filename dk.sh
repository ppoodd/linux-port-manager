#!/bin/bash
#====================================================
# Linux 端口管理脚本（精简版）
#====================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 检测防火墙类型
detect_firewall() {
    if command -v ufw &>/dev/null && ufw status &>/dev/null 2>&1; then
        echo "ufw"
    elif command -v firewall-cmd &>/dev/null && systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "firewalld"
    elif command -v iptables &>/dev/null; then
        echo "iptables"
    else
        echo "none"
    fi
}

# 显示菜单
show_menu() {
    echo -e "${GREEN}请选择操作:${NC}"
    echo "  1) 开放端口 (支持批量)"
    echo "  2) 关闭端口 (支持批量)"
    echo "  3) 查看使用端口"
    echo "  4) 查看空闲端口"
    echo "  5) 退出"
    echo
}

# 开放端口
open_ports() {
    local firewall_type=$(detect_firewall)
    echo -e "\n${BLUE}=== 开放端口 ===${NC}"
    echo -e "防火墙类型: ${GREEN}$firewall_type${NC}\n"
    echo -e "${YELLOW}格式: 单个端口(如 8080) 或 批量(如 80,443,8080 或 8000-8010)${NC}"
    read -p "请输入端口: " port_input

    read -p "请输入协议 (tcp/udp/both) [tcp]: " proto
    proto=${proto:-tcp}

    if [[ "$proto" != "tcp" && "$proto" != "udp" && "$proto" != "both" ]]; then
        echo -e "${RED}错误: 无效的协议${NC}"; return 1
    fi

    echo -e "\n${YELLOW}即将开放端口: $port_input/$proto${NC}"
    read -p "确认操作? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo "操作已取消"; return 0; fi

    local protocols=()
    [[ "$proto" == "both" ]] && protocols=("tcp" "udp") || protocols=("$proto")

    # 解析端口输入
    local ports=()
    if [[ "$port_input" =~ ^[0-9]+$ ]]; then
        ports=("$port_input")
    elif [[ "$port_input" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=$(echo "$port_input" | cut -d'-' -f1)
        local end=$(echo "$port_input" | cut -d'-' -f2)
        for ((i=start; i<=end; i++)); do ports+=("$i"); done
    else
        IFS=',' read -ra ports <<< "$port_input"
    fi

    # 验证端口
    for port in "${ports[@]}"; do
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
            echo -e "${RED}错误: 无效端口号 $port${NC}"; return 1
        fi
    done

    local count=0
    for port in "${ports[@]}"; do
        for p in "${protocols[@]}"; do
            case $firewall_type in
                ufw) ufw allow "$port/$p" && ((count++)) ;;
                firewalld) firewall-cmd --permanent --add-port="$port/$p" && ((count++)) ;;
                iptables) iptables -A INPUT -p "$p" --dport "$port" -j ACCEPT && ((count++)) ;;
                *) echo -e "${RED}未检测到防火墙${NC}"; return 1 ;;
            esac
        done
    done

    [[ "$firewall_type" == "firewalld" ]] && firewall-cmd --reload
    echo -e "${GREEN}成功开放 $count 个端口规则${NC}"
}

# 关闭端口
close_ports() {
    local firewall_type=$(detect_firewall)
    echo -e "\n${BLUE}=== 关闭端口 ===${NC}"
    echo -e "防火墙类型: ${GREEN}$firewall_type${NC}\n"
    echo -e "${YELLOW}格式: 单个端口(如 8080) 或 批量(如 80,443,8080 或 8000-8010)${NC}"
    read -p "请输入端口: " port_input

    read -p "请输入协议 (tcp/udp/both) [tcp]: " proto
    proto=${proto:-tcp}

    echo -e "\n${YELLOW}即将关闭端口: $port_input/$proto${NC}"
    read -p "确认操作? (y/n): " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then echo "操作已取消"; return 0; fi

    local protocols=()
    [[ "$proto" == "both" ]] && protocols=("tcp" "udp") || protocols=("$proto")

    # 解析端口输入
    local ports=()
    if [[ "$port_input" =~ ^[0-9]+$ ]]; then
        ports=("$port_input")
    elif [[ "$port_input" =~ ^[0-9]+-[0-9]+$ ]]; then
        local start=$(echo "$port_input" | cut -d'-' -f1)
        local end=$(echo "$port_input" | cut -d'-' -f2)
        for ((i=start; i<=end; i++)); do ports+=("$i"); done
    else
        IFS=',' read -ra ports <<< "$port_input"
    fi

    local count=0
    for port in "${ports[@]}"; do
        for p in "${protocols[@]}"; do
            case $firewall_type in
                ufw) ufw delete allow "$port/$p" 2>/dev/null && ((count++)) || echo -e "${YELLOW}规则不存在: $port/$p${NC}" ;;
                firewalld) firewall-cmd --permanent --remove-port="$port/$p" 2>/dev/null && ((count++)) ;;
                iptables) iptables -D INPUT -p "$p" --dport "$port" -j ACCEPT 2>/dev/null && ((count++)) || echo -e "${YELLOW}规则不存在: $port/$p${NC}" ;;
                *) echo -e "${RED}未检测到防火墙${NC}"; return 1 ;;
            esac
        done
    done

    [[ "$firewall_type" == "firewalld" ]] && firewall-cmd --reload
    echo -e "${GREEN}成功关闭 $count 个端口规则${NC}"
}

# 查看使用端口
show_used_ports() {
    echo -e "\n${BLUE}=== 已使用端口 ===${NC}\n"
    printf "%-8s %-10s %-20s %s\n" "协议" "端口" "进程" "PID"
    printf "%s\n" "----------------------------------------"

    ss -tunlp 2>/dev/null | awk 'NR>1 {
        proto = $1; state = $2; local = $5; proc = $7
        split(local, a, ":"); port = a[length(a)]
        pid = ""; if (match(proc, /pid=[0-9]+/)) pid = substr(proc, RSTART+4, RLENGTH-4)
        pname = ""; if (match(proc, /\(["][^"]+/)) pname = substr(proc, RSTART+2, RLENGTH-3)
        printf "%-8s %-10s %-20s %s\n", proto, port, pname, pid
    }' | sort -k2 -n | uniq -f1
    echo
}

# 获取防火墙已放行的端口
get_allowed_ports() {
    local firewall_type=$(detect_firewall)
    local ports=""
    case $firewall_type in
        ufw)
            ports=$(ufw status verbose 2>/dev/null | awk '/^[0-9]/ || /^[[:space:]]*[0-9]+/{
                for(i=1;i<=NF;i++) {
                    if($i ~ /^[0-9]+(,[0-9]+)*$/) {
                        split($i,p,",")
                        for(j in p) print p[j]
                    }
                }
            }' | sort -un)
            # 备用解析
            if [ -z "$ports" ]; then
                ports=$(ufw status 2>/dev/null | grep -oP '^[0-9]+(/[a-z]+)?\s' | grep -oP '^[0-9]+' | sort -un)
            fi
            ;;
        firewalld)
            ports=$(firewall-cmd --list-ports 2>/dev/null | tr ' ' '\n' | grep -v '^$' | cut -d'/' -f1 | sort -un)
            local rich_rules=$(firewall-cmd --list-rich-rules 2>/dev/null | grep -oP 'port="[^"]*"' | cut -d'"' -f2 | sort -un)
            if [ -n "$rich_rules" ]; then
                ports=$(printf "%s\n%s" "$ports" "$rich_rules" | sort -un)
            fi
            ;;
        iptables)
            ports=$(iptables -S INPUT 2>/dev/null | awk '/-j ACCEPT/ && /--dport/ {
                for(i=1;i<=NF;i++) if($i=="--dport") { print $(i+1); break }
            }' | sort -un)
            ;;
        *) echo ""; return ;;
    esac
    echo "$ports"
}

# 查看空闲端口
show_free_ports() {
    echo -e "\n${BLUE}=== 查看空闲端口 ===${NC}\n"
    echo -e "${YELLOW}空闲端口 = 防火墙已放行但没有程序监听的端口${NC}\n"

    # 获取防火墙已放行的端口
    local allowed_ports=$(get_allowed_ports)
    if [ -z "$allowed_ports" ]; then
        echo -e "${RED}未检测到防火墙放行规则或防火墙未运行${NC}"
        return 1
    fi

    # 获取当前程序监听的端口
    local listening_ports=$(ss -tunlp 2>/dev/null | awk 'NR>1 {split($5, a, ":"); port=a[length(a)]; print port}' | sort -n | uniq)

    echo -e "${CYAN}防火墙放行端口:${NC}"
    echo "$allowed_ports" | xargs -n 10 | while read line; do
        echo -e "${GREEN}  $line${NC}"
    done
    echo

    echo -e "${CYAN}程序监听端口:${NC}"
    echo "$listening_ports" | xargs -n 10 | while read line; do
        echo -e "${YELLOW}  $line${NC}"
    done
    echo

    # 计算差集：放行但未监听的端口
    local free_ports=""
    local free_count=0
    for port in $allowed_ports; do
        if ! echo "$listening_ports" | grep -qw "$port"; then
            free_ports="$free_ports $port"
            ((free_count++))
        fi
    done

    if [ $free_count -eq 0 ]; then
        echo -e "${GREEN}所有放行的端口都有程序在监听${NC}"
    else
        echo -e "${GREEN}=== 空闲端口 (已放行但未被使用) ===${NC}\n"
        echo "$free_ports" | tr ' ' '\n' | grep -v '^$' | xargs -n 10 | while read line; do
            echo "  $line"
        done
        echo
    fi
    echo -e "${GREEN}空闲端口数: $free_count${NC}  ${CYAN}放行端口总数: $(echo "$allowed_ports" | wc -w)${NC}"
}

# 主循环
main() {
    while true; do
        echo -e "${CYAN}╔════════════════════════════╗${NC}"
        echo -e "${CYAN}║    端口管理工具 v2.0      ║${NC}"
        echo -e "${CYAN}╚════════════════════════════╝${NC}"
        show_menu
        read -p "请输入选项 [1-5]: " choice
        case $choice in
            1) open_ports ;;
            2) close_ports ;;
            3) show_used_ports ;;
            4) show_free_ports ;;
            5) echo -e "${GREEN}再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
        echo; read -p "按回车键继续..."
        echo
    done
}

# 检查 root 权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 需要 root 权限运行${NC}"
    echo "请使用: sudo dk"
    exit 1
fi

main