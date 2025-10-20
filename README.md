# VLESS+XTLS+REALITY 与 Hysteria2 一键安装脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

## ⚠️ 重要免责声明

**使用本脚本即表示您已阅读、理解并同意以下所有条款。**

- 本脚本仅用于**合法用途**，使用者必须确保符合当地法律法规
- 开发者明确反对任何非法网络活动
- 使用者需自行承担使用风险，开发者不对任何损失负责
- 脚本不会收集用户数据，所有配置和密钥均存储在本地

---

## 简介

一个用于在Linux服务器上快速部署 VLESS+XTLS+REALITY (Xray) 和/或 Hysteria2 协议的Bash脚本。

## 功能特点

- 🚀 **一键安装/删除**: 支持安装和删除 VLESS+XTLS+REALITY (Xray) 和 Hysteria2
- 🌍 **多系统支持**: 自动检测并适配多种Linux发行版 (Ubuntu, Debian, CentOS, Alpine等)
- 🔒 **安全配置**: 自动生成UUID、密钥和证书
- 🛡️ **防火墙集成**: 自动配置nftables防火墙规则
- ⚡ **性能优化**: 自动检测并开启BBR拥塞控制算法
- 📝 **详细输出**: 提供完整的配置信息和服务管理命令

## 系统要求

- Linux操作系统 (支持apt/dnf/yum/apk包管理器的发行版)
- root权限或sudo权限

## 快速开始

### 1. 安装curl

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y curl

# CentOS/RHEL
sudo yum install -y curl

# Fedora
sudo dnf install -y curl

# Alpine Linux
sudo apk add --no-cache curl
```

### 2. 运行脚本

#### 方法1：分步执行（推荐）

```bash
# 下载脚本
curl -fsSL https://raw.githubusercontent.com/cloudyun233/hy2-vless/refs/heads/main/hy2vless.bash -o hy2vless.bash

# 赋予执行权限
chmod +x hy2vless.bash

# 执行脚本
bash hy2vless.bash
```

#### 方法2：进程替换

```bash
bash <(curl -Ls https://raw.githubusercontent.com/cloudyun233/hy2-vless/refs/heads/main/hy2vless.bash)
```

### 3. 选择操作

脚本菜单选项：
```
请选择要执行的操作（输入数字）:
  1) 安装 VLESS + XTLS + REALITY (Xray)
  2) 安装 Hysteria2
  3) 删除 Xray
  4) 删除 Hysteria2
选择 (1/2/3/4) [1]:
```

## 配置信息

### VLESS+XTLS+REALITY (Xray)

- **配置文件**: `/usr/local/etc/xray/config.json`
- **安装目录**: `/usr/local/share/xray/`
- **默认端口**: 443 (TCP)
- **认证方式**: UUID (自动生成)
- **安全特性**: XTLS + REALITY
- **目标站点**: `www.shinnku.com:443`

### Hysteria2

- **配置文件**: `/etc/hysteria/config.yaml`
- **安装目录**: `/etc/hysteria/`
- **默认端口**: 443 (UDP)
- **认证方式**: 密码 (自动生成)
- **TLS选项**: 支持ACME自动证书或自签名证书
- **伪装**: 使用 `https://www.shinnku.com/` 进行代理伪装

## Clash Meta 客户端配置

### VLESS + XTLS + REALITY

```yaml
- name: 服务器名称
  type: vless
  server: 服务器IP/域名
  port: 端口（默认443）
  udp: true
  uuid: 脚本生成的UUID
  flow: xtls-rprx-vision
  packet-encoding: xudp
  tls: true
  servername: www.shinnku.com
  alpn:
    - h2
    - http/1.1
  client-fingerprint: chrome
  skip-cert-verify: true
  reality-opts:
    public-key: 脚本生成的X25519公钥
    short-id: 脚本生成的Short ID
  network: tcp
```

### Hysteria2

```yaml
- name: 服务器名称
  type: hysteria2
  server: 服务器IP/域名
  port: 端口（默认443）
  password: 脚本生成的密码
  skip-cert-verify: true
  tfo: true
  # 可选配置
  # ports: 20000-20010  # 端口跳跃
  # obfs: salamander    # 混淆
  # obfs-password: 混淆密码
```

## 特殊场景

### NAT服务器

如果是NAT机器，请手动配置端口转发到443端口，并在客户端使用转发的端口连接。

### 校园网绕过

在某些限制性网络环境中，可通过以下方式绕过限制：

1. 安装Hysteria2服务（选择选项2）
2. 配置防火墙端口转发（以nftables为例）：

```bash
# 将53端口(DNS)流量转发到443端口
sudo nft add rule ip nat prerouting udp dport 53 redirect to 443

# 添加其他常用端口
sudo nft add rule ip nat prerouting udp dport 67 redirect to 443
sudo nft add rule ip nat prerouting udp dport 68 redirect to 443
```

3. 客户端使用53端口（或其他转发端口）连接

## 维护

### 定时重启任务

以下cron任务可用于每天UTC20:00自动重启服务器：

```
0 20 * * * /sbin/reboot
```

## 许可证与致谢

- 本项目采用MIT许可证
- 致谢：
  - [Xray-project](https://github.com/XTLS/Xray-core) - 提供Xray核心
  - [Hysteria](https://github.com/apernet/hysteria) - 提供Hysteria2协议实现

## 贡献

欢迎提交Issue和Pull Request来帮助改进此项目。