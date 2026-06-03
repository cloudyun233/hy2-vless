# 全局变量
SINGBOX_BIN="/usr/local/bin/sing-box"
SINGBOX_CONF_DIR="/usr/local/etc/sing-box"
SINGBOX_CONF_PATH="$SINGBOX_CONF_DIR/config.json"
NFT_CONF="/etc/nftables.conf"
DEFAULT_DOMAIN="www.cho-kaguyahime.com"

# 颜色输出函数
info(){ echo -e "\e[1;34m[信息]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[警告]\e[0m $*"; }
err(){ echo -e "\e[1;31m[错误]\e[0m $*"; }

# 检测操作系统类型，设置包管理器变量
check_sys(){
    if [[ -f /etc/redhat-release ]]; then
        RELEASE="centos"
        PM="yum"
    elif cat /etc/issue | grep -q -E -i "debian|ubuntu"; then
        RELEASE="debian"
        PM="apt"
    elif cat /etc/issue | grep -q -E -i "alpine"; then
        RELEASE="alpine"
        PM="apk"
    else
        err "不支持的操作系统"
        exit 1
    fi
}

install_dependencies(){
    info "正在安装依赖..."
    info "根据系统类型使用 $PM 安装必要依赖包"
    if [[ "$PM" == "apt" ]]; then
        apt update && apt install -y curl wget jq nftables openssl tar cron || { err "依赖安装失败"; return 1; }
    elif [[ "$PM" == "apk" ]]; then
        apk add curl wget jq nftables openssl tar cronie || { err "依赖安装失败"; return 1; }
        rc-update add crond
        rc-service crond start
    elif [[ "$PM" == "yum" ]]; then
        yum install -y curl wget jq nftables openssl tar cronie || { err "依赖安装失败"; return 1; }
        systemctl enable crond
        systemctl start crond
    fi
}

# 生成随机 UUID
get_random_uuid(){ uuidgen || cat /proc/sys/kernel/random/uuid; }

# 生成随机密码
get_random_password(){ openssl rand -base64 18; }
