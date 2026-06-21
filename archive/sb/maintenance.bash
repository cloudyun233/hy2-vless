# 清除所有入站配置
clear_config(){
    info "正在清除入栈配置..."

    # 清除证书文件
    local cert_files=(
        "$SINGBOX_CONF_DIR/singbox.crt"
        "$SINGBOX_CONF_DIR/singbox.key"
    )

    local cert_found=false
    for cert_file in "${cert_files[@]}"; do
        if [[ -f "$cert_file" ]]; then
            rm -f "$cert_file"
            cert_found=true
        fi
    done

    if [[ "$cert_found" == true ]]; then
        info "证书文件已清理。"
    fi

    # 只清除入栈配置，保留出站配置
    jq '.inbounds = []' "$SINGBOX_CONF_PATH" > "${SINGBOX_CONF_PATH}.tmp" && mv "${SINGBOX_CONF_PATH}.tmp" "$SINGBOX_CONF_PATH"

    # 清理防火墙
    if command -v nft >/dev/null; then
        nft flush table inet singbox_nat || true
        nft delete table inet singbox_nat || true
        nft delete table inet singbox_filter || true
    elif command -v firewall-cmd >/dev/null; then
        warn "Firewalld 用户请注意：脚本无法自动精确删除所有开放端口，请手动检查 'firewall-cmd --list-all'。"
        firewall-cmd --reload
    fi

    restart_singbox
    info "入栈配置已清除。"
}

# 运行服务器测试脚本
run_test_script(){ bash <(curl -Ls Check.Place); }

# 安装 BBRv3 内核优化
run_bbr(){ bash <(curl -l -s https://raw.githubusercontent.com/byJoey/Actions-bbr-v3/refs/heads/main/install.sh); }

# 运行 IP-Sentinel Agent 客户端脚本
run_ip_sentinel_agent(){
    info "正在执行 IP-Sentinel Agent 客户端脚本..."
    bash -c "$(curl -fsSL https://raw.githubusercontent.com/hotyue/IP-Sentinel/main/install.sh)"
}

# 卸载 Sing-box 及相关配置
uninstall_singbox(){
    rm -rf "$SINGBOX_BIN" "$SINGBOX_CONF_DIR"

    # 清理防火墙
    if command -v nft >/dev/null; then
        nft flush table inet singbox_nat || true
        nft delete table inet singbox_nat || true
        nft delete table inet singbox_filter || true
    fi

    if [[ "$RELEASE" == "alpine" ]]; then
        rc-service sing-box stop || true
        rc-update del sing-box || true
        rm /etc/init.d/sing-box || true
    else
        systemctl disable --now sing-box || true
        rm /etc/systemd/system/sing-box.service || true
        systemctl daemon-reload || true
    fi
    info "已卸载。"
}

# 配置定时重启任务（每月 1 日 20:00 UTC）
configure_cron_reboot(){
    info "正在检查并配置系统时间为 UTC..."

    current_timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || date +%Z)

    if [[ "$current_timezone" != "UTC" ]]; then
        info "当前时区不是 UTC，正在设置为 UTC..."
        if command -v timedatectl &>/dev/null; then
            timedatectl set-timezone UTC
            info "时区已设置为 UTC"
        else
            if [[ -f /etc/localtime ]]; then
                rm -f /etc/localtime
            fi
            ln -sf /usr/share/zoneinfo/UTC /etc/localtime
            info "时区已设置为 UTC (通过符号链接)"
        fi
    else
        info "当前时区已经是 UTC"
    fi

    # 显示当前时间
    info "当前系统时间: $(date '+%Y-%m-%d %H:%M:%S %Z')"

    info "正在配置每月 1 日 20:00 UTC 重启。"
    # 检查是否存在
    crontab -l 2>/dev/null | grep -v "/sbin/reboot" > mycron || true
    echo "0 20 1 * * /sbin/reboot" >> mycron
    crontab mycron
    rm mycron
    info "定时任务已添加。"
}
