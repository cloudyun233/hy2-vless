#!/bin/bash

# Caddy 部署与管理脚本
# 目标：反向代理 https://www.shinnku.com
# 功能：包管理器安装、交互式配置端口和域名、禁用HTTP3、卸载

# --- 颜色定义 ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# --- 检查 Root 权限 ---
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}错误：此脚本必须以 root 权限运行。${NC}"
        echo -e "请尝试使用 'sudo bash $0' 运行。"
        exit 1
    fi
}

# --- 识别操作系统 ---
detect_os() {
    OS_ID=""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
    else
        echo -e "${RED}无法识别的操作系统。${NC}"
        exit 1
    fi
}

# --- 1. 安装 Caddy (使用包管理器) ---
install_caddy() {
    detect_os
    
    echo -e "${GREEN}正在安装 Caddy...${NC}"
    
    if [ "$OS_ID" == "ubuntu" ] || [ "$OS_ID" == "debian" ]; then
        # Debian/Ubuntu
        echo "检测到 Debian/Ubuntu 系统。"
        apt install -y debian-keyring debian-archive-keyring apt-transport-https
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list
        apt update
        apt install -y caddy
        
    elif [ "$OS_ID" == "fedora" ] || [ "$OS_ID" == "centos" ] || [ "$OS_ID" == "rhel" ] || [ "$OS_ID" == "rocky" ] || [ "$OS_ID" == "almalinux" ]; then
        # RHEL/Fedora
        echo "检测到 RHEL/Fedora/CentOS (dnf) 系统。"
        dnf install -y 'dnf-command(copr)'
        dnf copr enable -y @caddy/caddy
        dnf install -y caddy
        
    else
        echo -e "${RED}不支持的操作系统: $OS_ID。请手动安装 Caddy。${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Caddy 安装完成。${NC}"
    configure_caddy
}

# --- 2. 配置 Caddy ---
configure_caddy() {
    local DOMAIN
    local PORT_CHOICE
    local CADDYFILE_CONTENT
    
    # 交互式输入域名
    while true; do
        read -p "请输入您的域名 (域名必须指向服务器ip): " DOMAIN
        if [ -z "$DOMAIN" ]; then
            echo -e "${RED}域名不能为空，请重新输入。${NC}"
        else
            break
        fi
    done
    
    # 交互式选择端口
    echo "请选择 Caddy 监听的 HTTPS 端口："
    echo "  1) 443 TCP (标准 HTTPS 端口配合hy2)"
    echo "  2) 8443 TCP (用于 VLESS 等回落)"
    
    while true; do
        read -p "请输入选项 [1 或 2]: " PORT_CHOICE
        case $PORT_CHOICE in
            1)
                echo -e "${YELLOW}警告：您选择了 443 端口。${NC}"
                echo -e "脚本将禁用 HTTP/3 (UDP 443)，以避免与 Hysteria2 等程序冲突。"
                echo -e "Caddy 将监听 ${GREEN}80/tcp${NC} (用于HTTP->HTTPS重定向) 和 ${GREEN}443/tcp${NC} (用于HTTPS)。"

                CADDYFILE_CONTENT=$(cat <<EOF
{
	# 把默认 HTTPS 端口改成 8443，这样 443 不会被监听
	https_port 8443
}

# 80：ACME 验证 + 重定向
{$DOMAIN}:80 {
	redir https://{$DOMAIN}:8443{uri}
}

# 8443：真正的业务端口（HTTP/1.1+HTTP/2）
{$DOMAIN}:8443 {
	reverse_proxy https://www.shinnku.com {
		header_up Host "www.shinnku.com"
	}
}
EOF
)
                break
                ;;
            2)
                echo -e "${YELLOW}警告：您选择了 8443 端口。${NC}"
                echo -e "请确保您在 443 端口的程序 (如 VLESS) 已正确配置 'fallback' 到 ${GREEN}127.0.0.1:8443${NC}。"
                echo -e "Caddy 将监听 ${GREEN}80/tcp${NC} (用于ACME验证和HTTP->HTTPS重定向) 和 ${GREEN}8443/tcp${NC} (用于HTTPS)。"

                CADDYFILE_CONTENT=$(cat <<EOF
{
	servers :443 {
		protocols h3
	}
    https_port 8443
}

# # 80 端口用于 ACME 验证和重定向
# $DOMAIN:80 {
#     redir https://$DOMAIN:8443{uri}
# }

# 8443 端口处理 HTTPS
$DOMAIN:8443 {
    reverse_proxy https://www.shinnku.com {
        # 必须设置 Host 头部
        header_up Host "www.shinnku.com"
    }
}
EOF
)
                break
                ;;
            *)
                echo -e "${RED}无效输入，请输入 1 或 2。${NC}"
                ;;
        esac
    done
    
    # 写入配置文件
    echo -e "${GREEN}正在写入 Caddyfile...${NC}"
    mkdir -p /etc/caddy
    echo "$CADDYFILE_CONTENT" > /etc/caddy/Caddyfile
    
    # 重启 Caddy
    echo -e "${GREEN}正在(重)启动 Caddy 服务...${NC}"
    systemctl daemon-reload
    systemctl enable caddy
    systemctl restart caddy
    
    echo -e "${GREEN}Caddy 配置完成。${NC}"
    echo "请稍等片刻，Caddy 正在后台申请 SSL 证书。"
    echo "您可以使用 'systemctl status caddy' 或 'journalctl -u caddy -f' 查看日志。"
}

# --- 3. 卸载 Caddy ---
uninstall_caddy() {
    echo -e "${YELLOW}正在停止并卸载 Caddy...${NC}"
    
    systemctl stop caddy
    systemctl disable caddy
    
    detect_os

    if [ "$OS_ID" == "ubuntu" ] || [ "$OS_ID" == "debian" ]; then
        # Debian/Ubuntu
        apt purge -y caddy
        rm -f /etc/apt/sources.list.d/caddy-stable.list
        rm -f /usr/share/keyrings/caddy-stable-archive-keyring.gpg
        apt update
        
    elif [ "$OS_ID" == "fedora" ] || [ "$OS_ID" == "centos" ] || [ "$OS_ID" == "rhel" ] || [ "$OS_ID" == "rocky" ] || [ "$OS_ID" == "almalinux" ]; then
        # RHEL/Fedora
        dnf remove -y caddy
        dnf copr disable -y @caddy/caddy
        
    else
        echo -e "${YELLOW}无法自动卸载 $OS_ID 的 Caddy 仓库，但 Caddy 软件包可能已被移除。${NC}"
    fi
    
    # 清理配置文件
    rm -f /etc/caddy/Caddyfile
    rm -f /etc/caddy/Caddyfile.autosave
    echo -e "${GREEN}Caddy 已卸载，配置文件 /etc/caddy/Caddyfile 已移除。${NC}"
}

# --- 主菜单 ---
main_menu() {
    check_root
    
    echo "========================================"
    echo " Caddy 简易部署脚本"
    echo " 目标: 反向代理 https://www.shinnku.com"
    echo "========================================"
    echo
    echo "请选择操作:"
    echo "  1) 安装并配置 Caddy"
    echo "  2) 卸载 Caddy"
    echo "  3) 退出"
    echo
    
    read -p "请输入选项 [1, 2 或 3]: " choice
    
    case $choice in
        1)
            install_caddy
            ;;
        2)
            uninstall_caddy
            ;;
        3)
            echo "退出脚本。"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新运行脚本。${NC}"
            exit 1
            ;;
    esac
}

# --- 脚本入口 ---
main_menu