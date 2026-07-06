# 使用 nftables 开放指定端口
open_port(){
    local port="$1"
    local proto="$2"

    if command -v nft >/dev/null; then
        local nfthandle
        nfthandle=$(nft list table inet singbox_filter 2>/dev/null)
        if [[ -z "$nfthandle" ]]; then
            nft add table inet singbox_filter || true
            nft add chain inet singbox_filter input { type filter hook input priority 0 \; policy accept \; } || true
        fi

        if ! nft list table inet singbox_filter 2>/dev/null | grep -q "${proto} dport ${port} accept"; then
            nft add rule inet singbox_filter input "${proto}" dport "$port" accept || true
        fi
        nft list ruleset > "$NFT_CONF"
    else
        warn "未找到 nftables，请手动打开端口 $port。"
    fi
}

# 智能选择端口：优先使用 443，若被其他协议占用则回退到 8443
get_preferred_port(){
    local protocol="$1" # 当前仅 hysteria2 使用（TUIC 已禁用）

    # 检查当前配置：443 端口是否已被非 vless（即 hysteria2）协议占用
    local current_port_443_proto
    current_port_443_proto=$(jq -r '.inbounds[]? | select(.listen_port==443) | select(.type != "vless") | .type' "$SINGBOX_CONF_PATH" 2>/dev/null || true)

    if [[ -z "$current_port_443_proto" ]]; then
        # 443 未被使用，直接占用
        echo "443"
        return
    fi

    if [[ "$current_port_443_proto" == "$protocol" ]]; then
        # 443 已经被自己占用了，继续使用
        echo "443"
        return
    fi

    # 443 被别人占用了，回退到 8443
    echo "8443"
}

# 配置 nftables DNAT 规则（用于端口跳跃）
configure_dnat(){
    local hops="$1"
    local dest_port="$2"

    info "正在清除由于端口跳跃设置的旧防火墙转发规则..."

    info "正在配置 NFTables 转发..."

    nft delete table inet singbox_nat 2>/dev/null || true

    nft add table inet singbox_nat
    nft add chain inet singbox_nat prerouting { type nat hook prerouting priority dstnat \; policy accept \; }

    # 解析端口列表，支持混合格式如：443,2053,2000-3000
    IFS=',' read -ra port_items <<< "$hops"
    for item in "${port_items[@]}"; do
        if [[ "$item" == *"-"* ]]; then
            # 范围格式：2000-3000
            nft add rule inet singbox_nat prerouting udp dport $item dnat to :$dest_port
        else
            # 单个端口
            nft add rule inet singbox_nat prerouting udp dport $item dnat to :$dest_port
        fi
    done

    nft list ruleset > "$NFT_CONF"

    if [[ "$RELEASE" == "alpine" ]]; then
        rc-update add nftables default
        rc-service nftables restart
    else
        systemctl enable nftables
        systemctl restart nftables
    fi
    info "NFTables 规则已更新并生效。"
}

# 交互式配置端口跳跃功能
config_port_hopping(){
    if ! command -v nft >/dev/null 2>&1; then
        err "端口跳跃功能需要 nftables 支持。"
        err "当前系统未安装 nftables，请先安装后重试。"
        err "Debian/Ubuntu: apt install nftables"
        err "Alpine: apk add nftables"
        return 1
    fi

    echo "=================================="
    echo "  当前防火墙转发规则 (nftables)"
    echo "=================================="
    if nft list table inet singbox_nat 2>/dev/null >/dev/null; then
        echo "表: inet singbox_nat"
        echo "--------------------------------"
        nft -a list chain inet singbox_nat prerouting 2>/dev/null || echo "无转发链"
        echo "--------------------------------"
        # 询问是否清除当前端口转发规则
        read -rp "是否清除当前端口转发规则？ [y/N]: " clear_rules
        if [[ "$clear_rules" =~ ^[Yy]$ ]]; then
            info "正在清除端口转发规则..."
            nft delete table inet singbox_nat 2>/dev/null || true
            info "端口转发规则已清除。"
            return 0
        fi
    else
        echo "暂无端口跳跃转发规则"
    fi
    echo "=================================="
    echo
    info "正在配置防火墙转发 (端口跳跃)..."

    local default_dest="443"
    read -rp "请输入目标端口 (即 Hy2 实际监听的端口) [默认: $default_dest]: " dest_port
    dest_port=${dest_port:-$default_dest}

    local default_hops="443,2053,2083,2087,2096,8443"
    echo "请输入接收端口（多个端口用逗号分隔，支持范围如 2000-3000）"
    read -rp "默认 [$default_hops]: " input_ports
    input_ports=${input_ports:-$default_hops}

    input_ports="${input_ports// /}"
    # 将中文逗号替换为英文逗号
    input_ports="${input_ports//，/,}"

    echo "--------------------------------"
    echo "目标端口: $dest_port"
    echo "跳转端口: $input_ports"
    echo "--------------------------------"
    read -rp "确认配置？这将覆盖现有的端口跳跃规则 [Y/n]: " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        info "已取消。"
        return
    fi

    configure_dnat "$input_ports" "$dest_port"
}
