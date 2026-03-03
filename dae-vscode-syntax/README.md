# DAE Local Syntax (VS Code)

本目录是一个本地可用的 VS Code 语法高亮扩展，针对 `.dae` 配置文件。

## 已支持高亮
- 注释：`# ...`
- 区块头：`global {}` / `routing {}` / `group {}` 等
- 键值：`key: value` 里的 key
- 路由运算符：`->`、`&&`、`||`
- 规则函数：`domain(...)`、`dip(...)`、`pname(...)` 等
- 布尔值：`true` / `false`
- 常见动作词：`direct` / `proxy` / `block` / `fallback`
- IP/CIDR、端口、URL、时间数值（如 `100ms` / `30s`）
- 组名与路由目标（如 `ai` / `brutal` / `fast` / `tiktok` / `tg`）
- 域名匹配（`geosite:*`、`geoip:*`、`suffix:*`、裸域名等）

## 持久保存（推荐）
1. 把本目录 `richang/dae-vscode-syntax` 放进 Git 仓库管理（GitHub/Gitea/本地私仓都可）
2. 每次改语法规则后提交版本，跨机器直接拉取仓库

## 一键安装脚本（推荐）
扩展目录内已提供两个脚本：
- `install-win.ps1`：Windows 安装到 `%USERPROFILE%\.vscode\extensions\dae-local-syntax`
- `install-linux.sh`：Linux/Arch 安装到 `~/.vscode/extensions/dae-local-syntax`

### Windows
```powershell
cd richang/dae-vscode-syntax
powershell -ExecutionPolicy Bypass -File .\install-win.ps1
```

### Linux / Arch
```bash
cd richang/dae-vscode-syntax
chmod +x ./install-linux.sh
./install-linux.sh
```

安装后重载 VS Code：`Developer: Reload Window`

## 打包成 VSIX（跨电脑分发）
如果你不想每台机器复制目录，可以打包后安装：

```bash
cd richang/dae-vscode-syntax
npm i -g @vscode/vsce
vsce package
```

生成 `*.vsix` 后，在任意机器安装：
```bash
code --install-extension dae-local-syntax-0.0.1.vsix
```

## 生效检查
1. 打开任意 `.dae` 文件（如 `config.dae`）
2. 右下角语言模式应显示 `DAE`
3. 若未自动识别，手动切换语言模式为 `DAE`

## 后续可扩展
- 增加更多 dae 关键字和内建函数
- 给不同动作组（`ai`/`tiktok`/`brutal`）做更细分 token scope
- 增加 snippets 与简单诊断
