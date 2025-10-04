#!/usr/bin/env bash
set -euo pipefail

# 精简版安装脚本：VLESS+XTLS+REALITY (Xray) + Hysteria2
# 官方安装脚本和对应目录
# hy：/etc/hysteria/
# 安装或升级到最新版本。
# bash <(curl -fsSL https://get.hy2.sh/)
# 移除 Hysteria 及相关服务
# bash <(curl -fsSL https://get.hy2.sh/) --remove

# xray：
# 安装目录/usr/local/share/xray/
# 配置文件目录/usr/local/etc/xray/
# 安装并升级 Xray-core 和地理数据，默认使用 User=nobody，但不会覆盖已有服务文件中的 User 设置
# bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
# 移除 Xray，包括 json 配置文件和日志
# bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge

# 对于alpine linux
# 安装 cURL
# apk add curl
# 下载安装脚本
# curl -O -L https://github.com/XTLS/Xray-install/raw/main/alpinelinux/install-release.sh
# 运行安装脚本
# ash install-release.sh
# 管理命令
# 启用 Xray 服务 (开机自启)
# rc-update add xray
# 禁用 Xray 服务 (取消自启)
# rc-update del xray
# 运行 Xray
# rc-service xray start
# 停止 Xray
# rc-service xray stop
# 重启 Xray
# rc-service xray restart

info(){ echo -e "\e[1;34m[信息]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[警告]\e[0m $*"; }
err(){ echo -e "\e[1;31m[错误]\e[0m $*"; }

# 需要root权限
if [[ "$(id -u)" -ne 0 ]]; then
  err "请以 root 用户执行本脚本（或使用 sudo）。退出。"
  exit 1
fi

# 检查必要的环境和工具
check_environment() {
  info "检查系统环境和必要工具..."
  
  # 检查 bash
  if ! command -v bash >/dev/null 2>&1; then
    err "未找到 bash，请先安装 bash。"
    exit 1
  fi
  
  # 检查是否使用 busybox 提供的 bash
  if bash --version 2>&1 | grep -qi "busybox" >/dev/null 2>&1; then
    err "检测到 bash 由 busybox 提供，请使用完整的 GNU bash。"
    exit 1
  fi
  
  # 检查 grep
  if ! command -v grep >/dev/null 2>&1; then
    err "未找到 grep，请先安装 grep。"
    exit 1
  fi
  
  # 检查是否使用 busybox 提供的 grep
  if grep --version 2>&1 | grep -qi "busybox" >/dev/null 2>&1; then
    err "检测到 grep 由 busybox 提供，请使用完整的 GNU grep。"
    exit 1
  fi
  
  # 检查 curl
  if ! command -v curl >/dev/null 2>&1; then
    err "未找到 curl，请先安装 curl。"
    exit 1
  fi
  
  # 检查是否使用 busybox 提供的 curl
  if curl --version 2>&1 | grep -qi "busybox" >/dev/null 2>&1; then
    err "检测到 curl 由 busybox 提供，请使用完整的 GNU curl。"
    exit 1
  fi
  
  # 检查 GNU Coreutils 工具集中的基本命令
  local coreutils_commands=("cat" "cp" "mv" "rm" "mkdir" "chmod" "chown" "ls" "sed" "awk")
  local missing_commands=()
  local busybox_commands=()
  
  for cmd in "${coreutils_commands[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing_commands+=("$cmd")
    elif "$cmd" --version 2>&1 | grep -qi "busybox" >/dev/null 2>&1; then
      busybox_commands+=("$cmd")
    fi
  done
  
  if [ ${#missing_commands[@]} -gt 0 ]; then
    err "缺少以下 GNU Coreutils 工具: ${missing_commands[*]}"
    err "请先安装 GNU Coreutils 工具集。"
    exit 1
  fi
  
  if [ ${#busybox_commands[@]} -gt 0 ]; then
    err "以下工具由 busybox 提供，而非 GNU Coreutils: ${busybox_commands[*]}"
    err "请使用完整的 GNU Coreutils 工具集替代 busybox 版本。"
    exit 1
  fi
  
  # 检查 useradd 命令
  if ! command -v useradd >/dev/null 2>&1; then
    warn "未找到 useradd，尝试安装..."
    case "$PM" in
      apt)
        apt-get update -y
        apt-get install -y shadow || warn "无法安装 shadow 包，请手动安装"
        ;;
      yum|dnf)
        yum install -y shadow-utils || dnf install -y shadow-utils || warn "无法安装 shadow-utils 包，请手动安装"
        ;;
      apk)
        apk add --no-cache shadow || warn "无法安装 shadow 包，请手动安装"
        ;;
      *)
        warn "无法识别包管理器，请手动安装包含 useradd 的包"
        ;;
    esac
    
    # 再次检查 useradd 是否安装成功
    if ! command -v useradd >/dev/null 2>&1; then
      warn "useradd 安装失败，某些功能可能受限"
    else
      info "useradd 已成功安装"
    fi
  else
    info "useradd 已安装"
  fi
  
  info "环境检查通过，所有必要工具已安装且不是通过 busybox 提供。"
}

# 检测包管理器/发行版
PM=""
if command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v dnf >/dev/null 2>&1; then PM=dnf
elif command -v yum >/dev/null 2>&1; then PM=yum
elif command -v apk >/dev/null 2>&1; then PM=apk
fi

info "检测到包管理器: ${PM:-(unknown)}"

# 执行环境检查
check_environment

# 默认值
XRAY_PORT_TCP=443
HY2_PORT_UDP=443
XRAY_CONF_DIR="/usr/local/etc/xray"
XRAY_CONF_PATH="$XRAY_CONF_DIR/config.json"
HY_CONF_DIR="/etc/hysteria"
HY_CONF_PATH="$HY_CONF_DIR/config.yaml"
HY_BIN_PATH="$HY_CONF_DIR/hysteria"

# 辅助函数
gen_uuid() {
  if command -v xray >/dev/null 2>&1; then
    xray uuid
    return 0
  fi
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen
    return 0
  fi
  err "无法生成 UUID，请确保安装了 xray 或 uuidgen 命令"
  return 1
}

rand_hex(){ openssl rand -hex "${1:-16}"; }

# 确保基本工具存在(curl/wget/openssl/GNU Coreutils)
ensure_pkgs(){
  info "确保基本工具已安装..."
  case "$PM" in
    apt)
      apt-get update -y
      apt-get install -y curl wget openssl coreutils bash grep passwd || true
      ;;
    yum)
      yum install -y curl wget openssl coreutils bash grep shadow-utils || true
      ;;
    dnf)
      dnf install -y curl wget openssl coreutils bash grep shadow-utils || true
      ;;
    apk)
      apk add --no-cache curl wget openssl bash grep shadow || true
      # Alpine 默认使用 busybox，需要额外安装 GNU 版本
      apk add --no-cache -X http://dl-cdn.alpinelinux.org/alpine/edge/community findutils || true
      ;;
    *)
      warn "无法识别包管理器，请确保 curl/wget/openssl/GNU Coreutils/bash/grep/useradd 可用。"
      ;;
  esac
  info "基本工具检查完成。"
}

ensure_pkgs

# 检测nft是否存在（仅使用nft）
HAS_NFT=false
if command -v nft >/dev/null 2>&1; then
  HAS_NFT=true
  info "检测到 nft，可用。"
else
  warn "未检测到 nft，将跳过防火墙自动配置。"
fi

# 菜单
cat <<'MENU'
请选择要执行的操作（输入数字）:
  1) 仅安装 VLESS + XTLS + REALITY (Xray)
  2) 仅安装 Hysteria2
  3) 仅删除 Xray
  4) 仅删除 Hysteria2
MENU
read -rp "选择 (1/2/3/4) [1]: " CHOICE
CHOICE=${CHOICE:-1}
INSTALL_XRAY=false
INSTALL_HY2=false
REMOVE_XRAY=false
REMOVE_HY2=false
[[ "$CHOICE" == "1" ]] && INSTALL_XRAY=true
[[ "$CHOICE" == "2" ]] && INSTALL_HY2=true
[[ "$CHOICE" == "3" ]] && REMOVE_XRAY=true
[[ "$CHOICE" == "4" ]] && REMOVE_HY2=true

###############################################################################
# 删除函数
###############################################################################
# 删除 Xray
remove_xray() {
  info "开始删除 Xray..."
  
  if [[ "$PM" == "apk" ]]; then
    info "检测到 Alpine 系统，使用 Alpine 专用删除流程..."
    rc-service xray stop 2>/dev/null || true
    rc-update del xray 2>/dev/null || true
    rm -rf /usr/local/bin/xray /usr/local/share/xray /usr/local/etc/xray /var/log/xray /etc/init.d/xray 2>/dev/null || true
    apk del unzip 2>/dev/null || true
    info "Alpine 系统上的 Xray 已删除"
  else
    info "使用官方删除脚本删除 Xray..."
    if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ remove --purge; then
      info "Xray 官方删除脚本已执行"
    else
      err "执行 Xray 官方删除脚本失败，请手动检查"
    fi
  fi
}

# 删除 Hysteria2
remove_hy2() {
  info "开始删除 Hysteria2..."
  
  if [[ "$PM" == "apk" ]]; then
    info "检测到 Alpine 系统，使用 Alpine 专用删除流程..."
    rc-service hysteria stop 2>/dev/null || true
    rc-update del hysteria 2>/dev/null || true
    rm -f /etc/init.d/hysteria 2>/dev/null || true
    rm -f "$HY_BIN_PATH" 2>/dev/null || true
    rm -rf "$HY_CONF_DIR" 2>/dev/null || true
    info "Alpine 系统上的 Hysteria2 已删除"
  else
    info "使用官方删除脚本删除 Hysteria2..."
    if bash <(curl -fsSL https://get.hy2.sh/) --remove; then
      info "Hysteria2 官方删除脚本已执行"
    else
      err "执行 Hysteria2 官方删除脚本失败，请手动检查"
    fi
  fi
}

# 执行删除操作
if [[ "$REMOVE_XRAY" == "true" ]]; then
  remove_xray
fi

if [[ "$REMOVE_HY2" == "true" ]]; then
  remove_hy2
fi

# 如果只是删除操作，完成后退出
if [[ "$REMOVE_XRAY" == "true" || "$REMOVE_HY2" == "true" ]] && [[ "$INSTALL_XRAY" != "true" && "$INSTALL_HY2" != "true" ]]; then
  info "删除操作完成"
  exit 0
fi

###############################################################################
# XRAY 安装与配置 (VLESS + REALITY)
###############################################################################
if [[ "$INSTALL_XRAY" == "true" ]]; then
  info "开始安装 Xray (VLESS+REALITY) — 使用官方推荐流程（优先尝试官方安装脚本）。"

  # 先执行安装操作
  if [[ "$PM" == "apk" ]]; then
    info "检测到 Alpine：使用 Xray 官方 Alpine 安装脚本。"
    curl -fsSL -o /tmp/xray-alpine-install.sh https://github.com/XTLS/Xray-install/raw/main/alpinelinux/install-release.sh || true
    if [[ -f /tmp/xray-alpine-install.sh ]]; then
      ash /tmp/xray-alpine-install.sh || warn "运行 Xray Alpine 安装脚本失败，请手动检查。"
    else
      warn "无法下载 Xray Alpine 安装脚本，跳过自动安装步骤。"
    fi
  else
    # 尝试主安装程序（适用于许多发行版）
    info "正在执行 Xray 官方安装脚本..."
    if bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install; then
      info "Xray 官方安装脚本已执行（或已安装）。"
    else
      err "执行 Xray 官方安装脚本失败，可能是网络问题或连接被重置。请检查网络连接或手动安装 Xray。"
      warn "脚本将生成示例配置供手动部署，但 Xray 可能未正确安装。"
    fi
  fi

  # 安装完成后，再进行配置
  mkdir -p "$XRAY_CONF_DIR"

  # 自动生成 UUID
  VLESS_UUID="$(gen_uuid)"
  info "自动生成 VLESS UUID: ${VLESS_UUID}"

  # 尝试使用 xray x25519 生成密钥
  XRAY_PRIV=""; XRAY_PUB=""
  if command -v xray >/dev/null 2>&1; then
    info "尝试运行 'xray x25519' 生成 X25519 密钥对（若可用）..."
    tmpf=$(mktemp)
    if xray x25519 >"$tmpf" 2>/dev/null; then
      XRAY_PRIV="$(grep -i '^PrivateKey:' "$tmpf" | awk '{print $2}' || true)"
      XRAY_PUB="$(grep -i '^Password:' "$tmpf" | awk '{print $2}' || true)"
    fi
    rm -f "$tmpf" || true
  else
    warn "未检测到 xray 二进制，无法自动生成 x25519 key。可在安装后运行 'xray x25519' 并将 privateKey 填入配置。"
  fi

  # 固定 REALITY dest / serverNames
  REALITY_DEST="www.shinnku.com:443"
  REALITY_SNI_JSON='["www.shinnku.com"]'

  # 默认生成 shortId
  SHORTID="$(openssl rand -hex 8)"
  SHORTID_JSON="[\"$SHORTID\"]"
  info "自动生成 Xray shortId: $SHORTID"

  info "写入 Xray 配置到: $XRAY_CONF_PATH"
  cat > "$XRAY_CONF_PATH" <<JSON
{
  "log": { "loglevel": "none" },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${XRAY_PORT_TCP},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${VLESS_UUID}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "dest": "${REALITY_DEST}",
          "serverNames": ${REALITY_SNI_JSON},
          "privateKey": "${XRAY_PRIV}",
          "shortIds": ${SHORTID_JSON}
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http","tls","quic"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom", "tag": "direct" }
  ]
}
JSON

  # 尝试启用/重启 xray 服务
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -qi xray; then
    systemctl daemon-reload || true
    systemctl enable --now xray || systemctl restart xray || warn "无法自动启动/重启 xray，请手动检查 systemctl status xray"
  elif [[ "$PM" == "apk" ]]; then
    # 在 Alpine 上 openrc 可能被 Xray 安装程序使用
    if command -v rc-update >/dev/null 2>&1; then
      rc-update add xray || true
      rc-service xray start || true
    fi
  else
    warn "未检测到标准 xray service unit，可能需手动启动或检查安装路径。"
  fi
fi

###############################################################################
# HYSTERIA2 安装与配置
###############################################################################
if [[ "$INSTALL_HY2" == "true" ]]; then
  info "开始安装 Hysteria2（优先尝试官方安装器，若为 Alpine 使用轻量二进制+openrc 流程）。"

  # 先执行安装操作
  if [[ "$PM" == "apk" ]]; then
    info "检测到 Alpine — 使用二进制下载 + openrc 注册 hysteria（参考 Alpine 专用流程）。"
    mkdir -p "$HY_CONF_DIR"
    
    # 检测系统架构
    ARCH=$(uname -m)
    case "$ARCH" in
      x86_64)
        HY_ARCH="hysteria-linux-amd64"
        info "检测到 x86_64 架构，将下载 amd64 版本"
        ;;
      aarch64|arm64)
        HY_ARCH="hysteria-linux-arm64"
        info "检测到 aarch64/arm64 架构，将下载 arm64 版本"
        ;;
      *)
        warn "不支持的架构: $ARCH，将默认使用 amd64 版本"
        HY_ARCH="hysteria-linux-amd64"
        ;;
    esac
    
    # 尝试下载最新的 hysteria 二进制
    if wget -q -O "$HY_BIN_PATH" "https://download.hysteria.network/app/latest/${HY_ARCH}" --no-check-certificate; then
      chmod 777 "$HY_BIN_PATH"
      info "hysteria 二进制已下载到 ${HY_BIN_PATH}"
    else
      warn "无法下载 hysteria 二进制，考虑使用官方安装脚本或检查网络。"
    fi
  else
    # 为非 Alpine 系统尝试官方安装程序
    info "正在执行 Hysteria2 官方安装脚本..."
    if bash <(curl -fsSL https://get.hy2.sh/); then
      info "调用 Hysteria 官方安装器完成（或已安装）。"
    else
      err "调用 Hysteria 官方安装器失败，已生成配置供手动部署。"
    fi
  fi

  # 安装完成后，再进行配置
  mkdir -p "$HY_CONF_DIR"

  # 自动生成 Hysteria 密码（auth）
  HY_PASS="$(rand_hex 16)"
  info "自动生成 Hysteria password: $HY_PASS"

  # 混淆可选
  read -rp "是否启用混淆 (salamander)？这会使得外部看起来是随机字节流，但会失去http3伪装 [y/N]: " _ob
  HY_OBFS=false
  HY_OBFS_PASS=""
  if [[ "${_ob,,}" =~ ^y(es)?$ ]]; then
    HY_OBFS=true
    HY_OBFS_PASS="$(rand_hex 16)"
    info "已为 obfs 生成密码: $HY_OBFS_PASS"
  fi

  # TLS 选择：ACME 或 自签名（不再接受已有证书文件）
  echo
  echo "Hysteria TLS 选择："
  select opt in "ACME 自动（需域名解析）" "生成自签名证书 (默认)"; do
    case $REPLY in
      1) HY_TLS_MODE="acme"; break;;
      2) HY_TLS_MODE="self"; break;;
      *) echo "请输入 1 或 2";;
    esac
  done

  HY_TLS_CERT=""; HY_TLS_KEY=""; HY_DOMAIN=""; HY_EMAIL=""
  if [[ "$HY_TLS_MODE" == "acme" ]]; then
    read -rp "请输入域名（必须解析到此 VPS IP）: " HY_DOMAIN
    read -rp "ACME 邮箱（可留空）: " HY_EMAIL
    # 对于 Alpine，acme 可由 get.hy2.sh 处理或使用 acme.sh
  else
    info "生成自签名证书到 /etc/hysteria/server.crt & server.key"
    mkdir -p "$HY_CONF_DIR"
    openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=www.shinnku.com" -days 36500 && sudo chown hysteria /etc/hysteria/server.key && sudo chown hysteria /etc/hysteria/server.crt
    HY_TLS_CERT="/etc/hysteria/server.crt"
    HY_TLS_KEY="/etc/hysteria/server.key"
    HY_TLS_MODE="file"
  fi

  # 为YAML构建 obfs 块和 tls 块
  OBFS_BLOCK=""
  if $HY_OBFS; then
    OBFS_BLOCK=$(cat <<-YOB
obfs:
  type: salamander
  salamander:
    password: "${HY_OBFS_PASS}"
YOB
)
  fi

  if [[ "$HY_TLS_MODE" == "acme" ]]; then
    TLS_BLOCK=$(cat <<-YTL
tls:
  acme:
    enabled: true
    domains:
      - ${HY_DOMAIN}
    email: "${HY_EMAIL:-}"
YTL
)
  else
    TLS_BLOCK=$(cat <<-YTL
tls:
  cert: "${HY_TLS_CERT}"
  key: "${HY_TLS_KEY}"
YTL
)
  fi

  # 写入 hysteria 配置
  info "写入 Hysteria 配置到 ${HY_CONF_PATH}"
  cat > "$HY_CONF_PATH" <<YAML
listen: :${HY2_PORT_UDP}

${TLS_BLOCK}

auth:
  type: password
  password: "${HY_PASS}"

${OBFS_BLOCK}

masquerade:
  type: proxy
  proxy:
    url: https://www.shinnku.com/
    rewriteHost: true
YAML

  # 设置配置文件最宽松权限
  chmod 777 "$HY_CONF_PATH"

  # 尝试启用/重启 hysteria 服务
  if [[ "$PM" == "apk" ]]; then
    # 创建 openrc 服务文件
    cat > "/etc/init.d/hysteria" <<'EOF'
#!/sbin/openrc-run

name="hysteria"
command="/etc/hysteria/hysteria"
command_args="server --config /etc/hysteria/config.yaml"
pidfile="/var/run/${name}.pid"
command_background="yes"

depend() {
        need networking
}
EOF
    chmod +x /etc/init.d/hysteria
    rc-update add hysteria default || true
    rc-service hysteria start || warn "尝试启动 hysteria 服务失败，请手动检查。"
  else
    # 如果可用，尝试启用 systemd
    if command -v systemctl >/dev/null 2>&1; then
      if systemctl list-unit-files | grep -qi hysteria-server; then
        systemctl daemon-reload || true
        systemctl enable hysteria-server.service || true
        systemctl restart hysteria-server.service || warn "无法自动重启 hysteria-server，请手动检查 systemctl status hysteria-server.service"
      fi
    fi
  fi
fi

###############################################################################
# 防火墙: 使用 nft 添加允许规则（仅 nft）
###############################################################################
info "为 Xray (TCP ${XRAY_PORT_TCP}) 与 Hysteria (UDP ${HY2_PORT_UDP}) 添加 nft 入站允许规则（若支持 nft）..."

if $HAS_NFT; then
  nft list table inet filter >/dev/null 2>&1 || nft add table inet filter
  nft list chain inet filter input >/dev/null 2>&1 || nft add chain inet filter input { type filter hook input priority 0 \; policy accept \; }

  nft add rule inet filter input tcp dport ${XRAY_PORT_TCP} ct state new,established accept >/dev/null 2>&1 || true
  nft add rule inet filter input udp dport ${HY2_PORT_UDP} ct state new,established accept >/dev/null 2>&1 || true

  info "已向 nft 添加放行规则 (tcp ${XRAY_PORT_TCP}, udp ${HY2_PORT_UDP})。"
else
  warn "系统未安装或找不到 nft，已跳过自动添加防火墙规则。请手动放行对应端口。"
fi

# 持久化 nft 选项（仅当 nft 可用时）
if $HAS_NFT; then
  echo
  read -rp "检测到 nft，是否将当前 nft ruleset 持久化到 /etc/nftables.conf 并尝试启用 nftables 服务？ [y/N]: " _p
  if [[ "${_p,,}" =~ ^y(es)?$ ]]; then
    nft list ruleset > /etc/nftables.conf
    if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -qi nftables; then
      systemctl enable --now nftables || warn "启用 nftables 服务失败，请手动检查。"
    elif command -v rc-update >/dev/null 2>&1; then
      # Alpine: nft 持久化可能有所不同
      warn "在 Alpine 环境中，请根据发行版习惯持久化 /etc/nftables.conf 并在启动脚本中加载。"
    fi
    info "已导出 /etc/nftables.conf 并尝试启用 nftables 服务。"
  else
    info "你选择不持久化 nft 规则。重启后请确保规则存在或手动恢复。"
  fi
fi

###############################################################################
# 检测并开启 BBR
###############################################################################
info "检测并开启 BBR (TCP 拥塞控制算法)..."

# 检查系统内核版本是否支持BBR (4.9+)
KERNEL_VERSION=$(uname -r | cut -d. -f1,2)
REQUIRED_VERSION="4.9"

if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$KERNEL_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
  info "内核版本 $KERNEL_VERSION 支持 BBR"
  
  # 检查BBR是否已开启
  if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
    info "BBR 已开启"
  else
    info "尝试开启 BBR..."
    
    # 设置使用BBR算法
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    # 应用设置
    sysctl -p
    
    # 验证BBR是否成功开启
    if sysctl net.ipv4.tcp_congestion_control | grep -q "bbr"; then
      info "BBR 已成功开启"
    else
      warn "BBR 开启失败，请手动检查"
    fi
  fi
else
  warn "内核版本 $KERNEL_VERSION 不支持 BBR，需要 4.9 或更高版本"
fi

###############################################################################
# 输出结果
###############################################################################

echo
info "================= 配置完成 — 以下为生成的配置文件/要点 ================="

after_exit(){
  # 只在安装操作完成后显示配置信息
  if [[ "$INSTALL_XRAY" == "true" || "$INSTALL_HY2" == "true" ]]; then
    if [[ "$INSTALL_XRAY" == "true" ]]; then
      echo "----- XRAY: $XRAY_CONF_PATH -----"
      if [[ -f "$XRAY_CONF_PATH" ]]; then
        sed -n '1,200p' "$XRAY_CONF_PATH" || true
      else
        echo "(未找到 Xray 配置文件 $XRAY_CONF_PATH)"
      fi
      echo
      echo "提示：若 X25519 privateKey 为空，请在服务器上运行 'xray x25519' 以生成 private/public 并把 privateKey 填入上面的 config.json。"
      echo "VLESS 连接要点："
      echo "  - UUID: ${VLESS_UUID}"
      [[ -n "${XRAY_PUB:-}" ]] && echo "  - X25519 public: ${XRAY_PUB}"
      echo "  - shortId: ${SHORTID}"
      echo
    fi

    if [[ "$INSTALL_HY2" == "true" ]]; then
      echo "----- Hysteria2: $HY_CONF_PATH -----"
      if [[ -f "$HY_CONF_PATH" ]]; then
        sed -n '1,200p' "$HY_CONF_PATH" || true
      else
        echo "(未找到 Hysteria 配置文件 $HY_CONF_PATH)"
      fi
      echo
      echo "Hysteria 连接要点："
      echo "  - password: ${HY_PASS}"
      if $HY_OBFS; then echo "  - obfs: salamander (password: ${HY_OBFS_PASS})"; fi
      echo
    fi

    echo "如需端口跳跃，请在防火墙/路由器上手动配置端口转发。"

    echo
    info "================= 安装目录信息 ================="
    echo "各组件的安装目录和配置文件位置："
    echo
    if [[ "$INSTALL_XRAY" == "true" ]]; then
      echo "----- Xray -----"
      echo "  - 安装目录: /usr/local/share/xray/"
      echo "  - 配置文件目录: /usr/local/etc/xray/"
      echo "  - 配置文件: $XRAY_CONF_PATH"
      echo
    fi

    if [[ "$INSTALL_HY2" == "true" ]]; then
      echo "----- Hysteria2 -----"
      echo "  - 安装目录: $HY_CONF_DIR"
      echo "  - 配置文件: $HY_CONF_PATH"
      if [[ "$PM" == "apk" ]]; then
        echo "  - 二进制文件: $HY_BIN_PATH"
      fi
      echo
    fi

    echo
    info "================= 服务管理命令 ================="
    echo "根据您的系统类型，使用以下命令管理服务："
    echo
    if command -v systemctl >/dev/null 2>&1; then
      echo "----- systemd 系统 (如 Ubuntu, CentOS, Debian 等) -----"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "Xray 服务:"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 状态检查: systemctl status xray"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 设置开机启动: systemctl enable xray"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 关闭开机启动: systemctl disable xray"
      [[ "$INSTALL_XRAY" == "true" ]] && echo ""
      [[ "$INSTALL_HY2" == "true" ]] && echo "Hysteria 服务:"
      if [[ "$INSTALL_HY2" == "true" ]]; then
        if [[ "$PM" == "apk" ]]; then
          echo "  - 状态检查: systemctl status hysteria"
          echo "  - 设置开机启动: systemctl enable hysteria"
          echo "  - 关闭开机启动: systemctl disable hysteria"
        else
          echo "  - 状态检查: systemctl status hysteria-server.service"
          echo "  - 设置开机启动: systemctl enable hysteria-server.service"
          echo "  - 关闭开机启动: systemctl disable hysteria-server.service"
        fi
      fi
    elif command -v rc-update >/dev/null 2>&1; then
      echo "----- OpenRC 系统 (如 Alpine Linux 等) -----"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "Xray 服务:"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 状态检查: rc-service xray status"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 设置开机启动: rc-update add xray"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 关闭开机启动: rc-update del xray"
      [[ "$INSTALL_XRAY" == "true" ]] && echo ""
      [[ "$INSTALL_HY2" == "true" ]] && echo "Hysteria 服务 (Alpine 系统使用 hysteria 作为服务名):"
      [[ "$INSTALL_HY2" == "true" ]] && echo "  - 状态检查: rc-service hysteria status"
      [[ "$INSTALL_HY2" == "true" ]] && echo "  - 设置开机启动: rc-update add hysteria"
      [[ "$INSTALL_HY2" == "true" ]] && echo "  - 关闭开机启动: rc-update del hysteria"
    else
      echo "----- 未知系统类型 -----"
      echo "请根据您的系统类型手动管理服务"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "Xray 服务可能的管理命令："
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 状态检查: systemctl status xray / rc-service xray status / service xray status"
      [[ "$INSTALL_XRAY" == "true" ]] && echo "  - 开机启动: systemctl enable/disable xray / rc-update add/del xray"
      [[ "$INSTALL_XRAY" == "true" ]] && echo ""
      [[ "$INSTALL_HY2" == "true" ]] && echo "Hysteria 服务可能的管理命令："
      if [[ "$INSTALL_HY2" == "true" ]]; then
        if [[ "$PM" == "apk" ]]; then
          echo "  - 状态检查: systemctl status hysteria / rc-service hysteria status / service hysteria status"
          echo "  - 开机启动: systemctl enable/disable hysteria / rc-update add/del hysteria"
        else
          echo "  - 状态检查: systemctl status hysteria-server.service / rc-service hysteria-server.service / service hysteria-server.service"
          echo "  - 开机启动: systemctl enable/disable hysteria-server.service / rc-update add/del hysteria-server.service"
        fi
      fi
    fi
  fi
  
  # 如果执行了删除操作，显示删除完成提示
  if [[ "$REMOVE_XRAY" == "true" || "$REMOVE_HY2" == "true" ]]; then
    echo
    info "================= 删除操作完成 ================="
    echo "已删除所选服务，相关配置文件和二进制文件已被移除。"
    echo "如果需要重新安装，请再次运行本脚本并选择安装选项。"
  fi
}

# 在结束时打印摘要
# 使用 trap 确保脚本在任何情况下都会调用 after_exit 函数
trap after_exit EXIT

# 脚本结束