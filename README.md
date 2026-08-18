# Solar Wanderer · 遨游太阳系

基于真实 NASA JPL 星历的浏览器端 1:1 实时太阳系探索应用（上游项目 [hyqzz/Solar-Wanderer](https://github.com/hyqzz/Solar-Wanderer)，MIT 协议）：NodeJS 一键启动 HTTPS Web，前端为 `wanderer/` 源码 Vite 构建产物（真实纹理贴图、物理大气散射、星空、彗星、小行星带、奥尔特云、程序化环境音效、自由飞行/地表行走/海洋下潜）。

- 前端源码位于 `wanderer/`，构建产物输出到根目录 `dist/`（纯静态，`base: './'` 支持任意子路径部署）
- 范围从太阳表面延伸至 10 万 AU 奥尔特云；中英双语（`dist/en/`）
- 自动生成 ECDSA prime256v1 自签证书（含 CN、SAN、法国上法兰西鲁贝地区字段、keyUsage、extendedKeyUsage）
- 证书默认有效期 365 天（1 年），提前 30 天自动续期
- Web 服务自动复用证书启用 HTTPS（证书不存在时降级为 HTTP）

## 本地构建前端

```bash
cd wanderer
npm install
npm run build    # 产物输出到根目录 dist/
npm test         # 47 项星历/物理精度测试（可选，离线）
```

## 部署教程

### 1. 上传平铺运行文件

把下面内容放到 Linux 服务器同一个工作目录，例如 `/home/container`：

```text
index.js
server.mjs
hy2_fakeweb.sh
dist/
```

最终目录结构应类似：

```text
/home/container/index.js
/home/container/server.mjs
/home/container/hy2_fakeweb.sh
/home/container/dist/index.html
```

### 3. 设置启动命令

面板 Startup Command 填：

```bash
node /home/container/index.js
```

`index.js` 会启动 HTTP Web 服务，并在同目录调用：

```bash
bash /home/container/hy2_fakeweb.sh
```

### 4. 设置环境变量

在服务器面板中填写自己的值，不要把真实值提交到仓库：

```bash
HTTP_LISTEN_PORT=YOUR_PORT
TLS_CERT_IP=YOUR_SERVER_IP
TLS_CERT_CN=YOUR_SERVER_DOMAIN_OR_IP
TLS_CERT_DNS=YOUR_SERVER_DOMAIN
TLS_EARLY_RENEW_DAYS=30
```

- `TLS_CERT_IP` - 证书 IP 地址（默认 51.75.118.151，必须设置为你的服务器真实 IP）
- `TLS_CERT_CN` - 证书 CN 名称（默认同 TLS_CERT_IP）
- `TLS_CERT_DNS` - 证书 DNS 名称（默认同 HY2_SNI）
- `TLS_EARLY_RENEW_DAYS` - 提前多少天续期（默认 30）
- `FILE_PATH` - 数据根目录，存放密钥、证书、缓存等（默认 `.npm/video`）
- `FRONTEND_DIST_DIR` - 前端产物目录（默认 `./dist`）
- `TLS_CERT_PATH` - 证书文件路径（默认 `${FILE_PATH}/cert.pem`）
- `TLS_KEY_PATH` - 私钥文件路径（默认 `${FILE_PATH}/private.key`）
- `TRUST_PROXY` - 是否信任 `X-Forwarded-For` 头（默认 `false`，仅在反向代理后开启）

### 5. 访问页面

启动后访问（自签证书需要浏览器点击“继续访问”）：

```text
https://YOUR_SERVER_IP:YOUR_PORT/
```

英文版：`https://YOUR_SERVER_IP:YOUR_PORT/en/`

### 6. 更新页面

修改 `wanderer/` 源码后重新构建并上传新的 `dist/` 覆盖服务器上的旧版本：

```bash
cd wanderer
npm run build
```
