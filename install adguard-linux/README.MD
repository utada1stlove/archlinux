# Arch Linux 安装与使用 AdGuard for Linux（AdGuard CLI）完整指南（含 HTTPS 过滤 + 常见坑）

> 适用场景：Arch Linux 桌面环境，想要 **系统级全局过滤**（Automatic mode），并启用 **HTTPS Filtering（MITM 解密过滤）**。  
> 本文以 `adguard-cli` 为核心，包含安装、启用、证书信任、第三方规则订阅、开机自启，以及我们实际踩过的坑。

---

## 目录

- [1. 你装的是什么：AdGuard for Linux vs AdGuard Home](#1-你装的是什么adguard-for-linux-vs-adguard-home)
- [2. 安装方式选择（推荐 AUR）](#2-安装方式选择推荐-aur)
- [3. 启动与 Automatic mode（系统全局）](#3-启动与-automatic-mode系统全局)
- [4. HTTPS Filtering 必要前提：安装并信任 CA 证书](#4-https-filtering-必要前提安装并信任-ca-证书)
- [5. 验证是否真的过滤了（强验证）](#5-验证是否真的过滤了强验证)
- [6. 使用第三方规则（只用一个 merged_rules.txt）](#6-使用第三方规则只用一个-merged_rulestxt)
- [7. 解决 Custom Filter “non-trusted”](#7-解决-custom-filter-non-trusted)
- [8. 是否需要语言过滤器（AdGuard Chinese）？](#8-是否需要语言过滤器adguard-chinese)
- [9. 开机自启（systemd user service，含 fish 坑修复）](#9-开机自启systemd-user-service含-fish-坑修复)
- [10. 常见故障排查（我们遇到的坑）](#10-常见故障排查我们遇到的坑)
- [11. 卸载与清理](#11-卸载与清理)

---

## 1. 你装的是什么：AdGuard for Linux vs AdGuard Home

- **AdGuard Home**：自建 DNS 服务器（更适合路由器/局域网 DNS）。
- **AdGuard for Linux（AdGuard CLI）**：客户端系统级过滤器，可做 **HTTP(S) 过滤、DNS 过滤、脚本与规则**，并支持 **Automatic mode** 让系统全局流量自动走代理。

本文讲的是 **AdGuard for Linux（adguard-cli）**。

---

## 2. 安装方式选择（推荐 AUR）

### 2.1 推荐：AUR 安装（易升级/卸载，符合 pacman 管理习惯）

使用 `yay`：

```bash
yay -S adguard-cli-bin
```

确认安装成功：

```bash
adguard-cli --version
command -v adguard-cli
```

> 记住 `command -v adguard-cli` 输出的路径，后面写 systemd service 会用到。

------

## 3. 启动与 Automatic mode（系统全局）

### 3.1 启动

```bash
adguard-cli start
```

第一次启动时可能会提示（关键）：

> Automatic mode requires root helper to be set up, do you want to set it up? (yes/no)

选择 `yes`，它会安装并设置 SUID helper，例如：

- `Setting SUID bit on /usr/share/adguard-cli/adguard_root_helper`
- `SUID bit set successfully`

启动成功后通常会看到类似：

- HTTP proxy: `127.0.0.1:3129`
- SOCKS5 proxy: `127.0.0.1:1081`
- `System-wide automatic filtering is enabled`

### 3.2 状态

```bash
adguard-cli status
```

如果看到：

- `The AdGuard proxy server is running`
- `System-wide automatic filtering is enabled`

说明 **AdGuard 服务已运行 + 全局自动过滤开启**。

------

## 4. HTTPS Filtering 必要前提：安装并信任 CA 证书

> HTTPS Filtering 本质是 **MITM 解密**：AdGuard 会签发站点证书给浏览器，必须让系统/浏览器信任 AdGuard 的本地 CA，否则会出现证书错误或无法过滤。

### 4.1 找到 AdGuard CLI 的证书位置

AdGuard CLI 工作目录通常在：

- `~/.local/share/adguard-cli/`

用下面命令搜索证书：

```bash
find ~/.local/share/adguard-cli -maxdepth 4 -type f | grep -Ei 'crt|cer|pem|ca|adguard'
```

我们实际环境中常见的是：

- `~/.local/share/adguard-cli/SSL/AdGuard CLI.cer` ✅（推荐导入系统信任）
- `~/.local/share/adguard-cli/AdGuard CLI.pem`（可能包含私钥，不推荐直接导入系统）

### 4.2 导入到 Arch 系统信任库（推荐使用 .cer）

将证书拷贝到 trust anchors：

```bash
sudo install -Dm644 "$HOME/.local/share/adguard-cli/SSL/AdGuard CLI.cer" \
  "/etc/ca-certificates/trust-source/anchors/adguard-cli-ca.crt"

sudo trust extract-compat
```

验证系统是否已信任（可选）：

```bash
trust list | grep -i "AdGuard CLI" -n
```

如果能看到类似 `label: AdGuard CLI`，说明成功。

### 4.3 Firefox 必做：让 Firefox 信任系统根证书

Firefox 常见默认不完全使用系统证书库，建议开启：

1. 地址栏打开：`about:config`
2. 搜索：`security.enterprise_roots.enabled`
3. 设置为：`true`
4. **完全退出并重启 Firefox**

> 如果你是 Flatpak 版 Firefox，证书更容易“隔离”，此设置尤为关键。
> 若仍不生效，需在 Firefox 内手动导入证书：
> Settings → Privacy & Security → Certificates → View Certificates → Authorities → Import → 选择 `AdGuard CLI.cer`

------

## 5. 验证是否真的过滤了（强验证）

### 5.1 最强验证：看证书 Issuer（证明 HTTPS 解密生效）

在 Firefox 打开 HTTPS 网站 → 点击 🔒 → 查看证书：

- ✅ 如果 Issuer/颁发者出现 `AdGuard` / `AdGuard CLI`：HTTPS Filtering 正在工作
- ❌ 如果 Issuer 还是 Let’s Encrypt / DigiCert：说明该连接未被 MITM（可能被排除、未信任证书、或走了 HTTP3/QUIC）

### 5.2 AdGuard 侧证据：访问日志（证明 Firefox 流量确实经过 AdGuard）

```bash
tail -n 200 ~/.local/share/adguard-cli/logs/access.log | grep -i firefox | tail -n 30
```

我们实际看到过类似条目（关键字段）：

- `"firefox" HTTP2 ... BLOCKED ...`
- `redirect=noopjson,domain=...`

这说明 **Firefox 流量经过 AdGuard 且规则生效拦截**（不仅仅是 DNS）。

### 5.3 对照实验：停止 AdGuard 看差异

```bash
adguard-cli stop
# 用浏览器刷新同一页面观察广告/请求变化
adguard-cli start
```

------

## 6. 使用第三方规则（只用一个 merged_rules.txt）

> 你可能以前在 Windows / AdGuardHome 用一份“每日更新的合并规则”，希望在 AdGuard CLI 也只用这一份。

关键点：

- `filters add` 只能加 **内置过滤器（按 ID/名称）**
- 第三方 URL 订阅必须用 `filters install`

假设你的规则 URL 是：

```
https://raw.githubusercontent.com/utada1stlove/adguardhome/main/merged_rules.txt
```

### 6.1 安装自定义订阅（正确方式）

```bash
adguard-cli filters install "https://raw.githubusercontent.com/utada1stlove/adguardhome/main/merged_rules.txt"
```

### 6.2 查看已安装 filters

```bash
adguard-cli filters list
```

你会看到 Custom filters 下出现一个 ID（例如 `-10001`）。

### 6.3 更新订阅（AdGuard 会拉取远程最新内容，无需你手动下载到本地）

```bash
adguard-cli filters update
```

> 这就是“不下载到本地也能每日更新”的正确路径：由 AdGuard CLI 管理订阅并更新。

------

## 7. 解决 Custom Filter “non-trusted”

很多版本里，自定义订阅默认标记为 `[non-trusted]`。这会影响某些规则能力/行为。

例如 `filters list` 里出现：

- `AdBlock DNS [non-trusted]`

解决方法：把该 filter 设置为 trusted：

```bash
adguard-cli filters set-trusted -10001 true
```

再确认：

```bash
adguard-cli filters list
```

------

## 8. 是否需要语言过滤器（AdGuard Chinese）？

你可能会看到启用项里还有：

- `224 | AdGuard Chinese filter`

是否要关掉取决于你的目标：

### 8.1 目标是“极简：只用一个 merged_rules.txt”

建议把 224 关掉，保证只有一份规则在生效：

```bash
adguard-cli filters disable 224
adguard-cli filters update
```

### 8.2 目标是“效果更强/更省心”

建议先保留 224 观察一段时间：

- 优点：对中文站点的补强通常更明显
- 缺点：误杀概率略增（出现问题再关或加白名单）

------

## 9. 开机自启（systemd user service，含 fish 坑修复）

> `adguard-cli start` 默认不会自动开机自启，你需要自己建 service。

### 9.1 先检查是否已经有自启 unit

```bash
systemctl list-unit-files | grep -i adguard || true
systemctl --user list-unit-files | grep -i adguard || true
```

### 9.2 推荐：创建 systemd user 服务（登录后自动启动）

#### 9.2.1 ⚠️ fish 坑：heredoc 写法会报错

在 fish 里运行下面这种会报：

```
fish: 预期 a string，但找到 a redirection
cat > ... <<'EOF'
```

解决：用 `bash -lc` 来执行 heredoc（最简单、最不容易错）。

#### 9.2.2 创建 user service（fish 兼容写法）

先把 `command -v adguard-cli` 的路径记下来（假设是 `/usr/bin/adguard-cli`，你要按实际替换）。

在 fish 里执行：

```fish
bash -lc 'mkdir -p ~/.config/systemd/user && cat > ~/.config/systemd/user/adguard-cli.service <<'"'"'EOF'"'"'
[Unit]
Description=AdGuard CLI
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/adguard-cli start --no-interactive
ExecStop=/usr/bin/adguard-cli stop
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF'
```

> **注意**：把 `ExecStart/ExecStop` 的路径替换成 `command -v adguard-cli` 的输出。

#### 9.2.3 启用自启

```bash
systemctl --user daemon-reload
systemctl --user enable --now adguard-cli.service
systemctl --user status adguard-cli.service --no-pager
```

------

## 10. 常见故障排查（我们遇到的坑）

### 10.1 `status` 提示新增 missing keys / default value

例如：

- `Key ... was missing in the settings and has been added with the default value`

这通常是 **配置文件字段升级/补全**，不是错误。继续启动即可。

### 10.2 `filters add URL` 报 “No filters found”

原因：`filters add` 只支持内置过滤器（ID/名称），不支持 URL。
正确做法：用 `filters install URL`。

### 10.3 HTTPS Filtering 不生效/Firefox 仍不拦截

优先检查：

1. 系统是否信任证书：
   `trust list | grep -i "AdGuard CLI" -n`
2. Firefox 是否开启 `security.enterprise_roots.enabled=true`
3. 是否走 HTTP3/QUIC 导致绕过：
   Firefox `about:config` → `network.http.http3.enabled=false` 试试（重启 Firefox）

### 10.4 某些应用打不开/证书报错

可能原因：

- 证书固定（pinning）
- 被 MITM 后应用拒绝连接

解决思路：

- 把域名加入 `https_exclusions.txt`（不对它做 HTTPS filtering）
- 或者针对特定应用使用 `bypass_https`（见 `browsers.yaml` / 应用规则）

### 10.5 如何确认 Firefox 确实被过滤

看 `access.log`：

```bash
tail -n 200 ~/.local/share/adguard-cli/logs/access.log | grep -i firefox | tail -n 30
```

出现 `BLOCKED` 就是明确证据。

------

## 11. 卸载与清理

AUR 安装的卸载：

```bash
yay -Rns adguard-cli-bin
```

（可选）清理用户数据目录：

```bash
rm -rf ~/.local/share/adguard-cli
```

（可选）清理 systemd user unit：

```bash
systemctl --user disable --now adguard-cli.service || true
rm -f ~/.config/systemd/user/adguard-cli.service
systemctl --user daemon-reload
```

------

## 附：常用命令速查

```bash
adguard-cli start
adguard-cli stop
adguard-cli restart
adguard-cli status

adguard-cli filters list
adguard-cli filters install "<URL>"
adguard-cli filters enable <ID>
adguard-cli filters disable <ID>
adguard-cli filters update
adguard-cli filters set-trusted <ID> true
```

------

> 如果你要把本文配成“最小可用 + 最强拦截”的模板，建议 README 里明确两种模式：
>
> - 极简：仅一个自定义 merged_rules.txt
> - 增强：merged_rules + AdGuard Chinese filter（224）并给出误杀排查方式

