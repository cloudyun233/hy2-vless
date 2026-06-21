# 显示交互式菜单
show_menu(){
    echo "=================================="
    echo "        Sing-box 一键配置          "
    echo "=================================="
    echo "1. 安装/更新 Sing-box"
    echo "2. 配置 VLESS Reality (Vision)"
    echo "3. 配置 Hysteria2"
    echo "4. 配置 TUIC v5"
    echo "5. 配置防火墙转发(只支持nftable)"
    echo "6. 清除入栈配置"
    echo "7. 卸载 Sing-box"
    echo "8. 服务器相关测试"
    echo "9. 安装 BBRv3(若想要更好的优化,可前往https://xanmod.org/)"
    echo "10. 每月自动重启 (20:00 UTC 每月1日)"
    echo "11. 执行 IP-Sentinel Agent 客户端脚本"
    echo "0. 退出"
    read -rp "选择: " choice
    case $choice in
        1) install_dependencies; install_singbox ;;
        2) config_vless ;;
        3) config_hy2 ;;
        4) config_tuic ;;
        5) config_port_hopping ;;
        6) clear_config ;;
        7) uninstall_singbox ;;
        8) run_test_script ;;
        9) run_bbr ;;
        10) configure_cron_reboot ;;
        11) run_ip_sentinel_agent ;;
        0) exit 0 ;;
        *) echo "无效选择";;
    esac
}
