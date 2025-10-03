# hy2vless - VLESS+XTLS+REALITY 与 Hysteria2 一键安装脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

一个用于在Linux服务器上快速部署 VLESS+XTLS+REALITY (Xray) 和/或 Hysteria2 协议的Bash脚本。

## 功能特点

- 🚀 **一键安装**: 支持单独或同时安装 VLESS+XTLS+REALITY (Xray) 和 Hysteria2
- 🌍 **多系统支持**: 自动检测并适配多种Linux发行版 (Ubuntu, Debian, CentOS, Alpine等)
- 🔒 **安全配置**: 自动生成UUID、密钥和证书
- 🛡️ **防火墙集成**: 自动配置nftables防火墙规则
- ⚡ **性能优化**: 自动检测并开启BBR拥塞控制算法
- 📝 **详细输出**: 提供完整的配置信息和服务管理命令

## 系统要求

- Linux操作系统 (支持apt/dnf/yum/apk包管理器的发行版)
- root权限或sudo权限

## 安装与使用

### 1. 确保系统已安装curl

如果系统中没有安装curl，请先执行以下命令安装：

**Ubuntu/Debian:**
```bash
sudo apt update && sudo apt install -y curl
```

**CentOS/RHEL:**
```bash
sudo yum install -y curl
```

**Fedora:**
```bash
sudo dnf install -y curl
```

**Alpine Linux:**
```bash
sudo apk add --no-cache curl
```

### 2. 在线下载并运行脚本

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/yourusername/hy2vless/main/hy2vless.bash)
```

### 3. 选择安装选项

脚本会显示以下菜单:
```
请选择要安装的协议（输入数字）:
  1) 仅安装 VLESS + XTLS + REALITY (Xray)
  2) 仅安装 Hysteria2
  3) 两者都安装
选择 (1/2/3) [1]:
```

根据需要输入对应的数字并按回车。

## 配置详情

### VLESS+XTLS+REALITY (Xray)

- **配置文件位置**: `/usr/local/etc/xray/config.json`
- **默认端口**: 443 (TCP)
- **认证方式**: UUID (自动生成)
- **安全特性**: XTLS + REALITY

### Hysteria2

- **配置文件位置**: `/etc/hysteria/config.yaml`
- **默认端口**: 443 (UDP)
- **认证方式**: 密码 (自动生成)
- **TLS选项**: 支持ACME自动证书或自签名证书

## 客户端配置

脚本运行完成后，会显示以下连接信息：

### VLESS+XTLS+REALITY

- **UUID**: 自动生成的UUID
- **X25519 Public Key**: 自动生成的公钥
- **Short ID**: 自动生成的短ID

### Hysteria2

- **密码**: 自动生成的密码
- **混淆**: 如果启用，会显示混淆类型和密码

## 许可证

本项目采用MIT许可证 - 详情请参阅 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交Issue和Pull Request来帮助改进此项目。

## 免责声明

本脚本仅用于合法用途。使用者需自行承担使用风险，并确保遵守当地法律法规。开发者不对使用本脚本造成的任何后果负责。

## 致谢

- [Xray-project](https://github.com/XTLS/Xray-core) - 提供Xray核心
- [Hysteria](https://github.com/apernet/hysteria) - 提供Hysteria2协议实现