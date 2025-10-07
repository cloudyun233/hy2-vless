# VLESS+XTLS+REALITY 与 Hysteria2 一键安装脚本

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue.svg)](https://www.gnu.org/software/bash/)

## ⚠️ 重要免责声明

**请仔细阅读以下免责声明，使用本脚本即表示您已阅读、理解并同意以下所有条款。**

### 法律合规性
- 本脚本仅用于**合法用途**，包括但不限于学术研究、网络安全测试、个人隐私保护等符合当地法律法规的场景
- 使用者**必须**确保其使用行为符合所在国家/地区的法律法规
- 开发者**明确反对**任何形式的非法网络活动，包括但不限于未经授权的网络访问、数据窃取、网络攻击等

### 使用风险
- 本脚本按"原样"提供，**不提供任何形式的明示或暗示担保**，包括但不限于适销性、特定用途适用性和非侵权性的担保
- 使用者需**自行承担**使用本脚本可能带来的所有风险，包括但不限于系统安全风险、数据丢失风险、法律风险等
- 开发者**不对**使用本脚本可能导致的任何直接或间接损失负责，包括但不限于数据丢失、设备损坏、法律纠纷等

### 安全提醒
- 本脚本部署的服务可能涉及网络流量转发，请确保您有合法权限进行相关操作
- 请妥善保管脚本生成的所有密钥、证书和配置信息，**切勿泄露**给未经授权的人员
- 建议定期更新系统和相关软件，以确保安全性
- 在生产环境使用前，请充分测试并评估安全性

### 隐私与数据
- 本脚本**不会收集**任何用户数据或个人信息
- 脚本运行过程中生成的所有配置和密钥均存储在**本地**，不会上传到任何远程服务器
- 使用者需自行负责保护服务器和客户端的数据安全

### 责任限制
- 在任何情况下，开发者均不对因使用或无法使用本脚本而导致的任何利润损失、数据丢失、业务中断或其他间接、特殊、偶然或后果性损害承担责任
- 开发者保留随时修改、更新或终止本脚本的权利，恕不另行通知

### 最终条款
- 如您不同意以上任何条款，请**立即停止使用**本脚本
- 本免责声明的解释权归开发者所有，开发者有权随时修改免责声明内容
- 如有疑问，请咨询相关法律专业人士

---

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
**然后你需要自行配置客户端连接信息。**

### VLESS+XTLS+REALITY

- **UUID**: 自动生成的UUID
- **X25519 Public Key**: 自动生成的公钥
- **Short ID**: 自动生成的短ID

### Hysteria2

- **密码**: 自动生成的密码
- **混淆**: 如果启用，会显示混淆类型和密码

## Clash Meta 客户端配置模板

以下是 Clash Meta 客户端的配置模板，你可以根据脚本输出的实际值进行填充：
若是nat服务器，端口填写你的外部端口

### VLESS + XTLS + REALITY 配置模板

```yaml
- name: 你想取的的名字
  type: vless
  server: 你的服务器IP/域名
  port: 你连接的端口（默认443）
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
  skip-cert-verify: false
  reality-opts:
    public-key: 脚本生成的X25519公钥
    short-id: 脚本生成的Short ID
  network: tcp
```

### Hysteria2 配置模板

```yaml
- name: 你想取的名字
  type: hysteria2
  server: 你的服务器IP/域名
  port: 你连接的端口（默认443）
  # 若使用端口跳跃功能，请填写以下配置：
  #ports: 例如20000-20010
  password: 脚本生成的密码
  skip-cert-verify: true
  # 若使用混淆功能，请填写以下配置：
  # obfs: salamander
  # obfs-password: 脚本生成的混淆密码
  tfo: true
```

## 许可证

本项目采用MIT许可证 - 详情请参阅 [LICENSE](LICENSE) 文件。

## 贡献

欢迎提交Issue和Pull Request来帮助改进此项目。

## 致谢

- [Xray-project](https://github.com/XTLS/Xray-core) - 提供Xray核心
- [Hysteria](https://github.com/apernet/hysteria) - 提供Hysteria2协议实现