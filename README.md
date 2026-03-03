# Arch Linux 空间清理指南（200G 分区实用版）

这个目录提供了 8 个脚本，目标是：

- 先看清楚空间占用
- 优先做低风险清理
- 在需要时再做深度清理

## 文件结构

- `scripts/space-clean-menu.sh`: 数字菜单入口（推荐）
- `scripts/space-check.sh`: 查看当前磁盘占用和常见可清理项
- `scripts/space-clean-safe.sh`: 安全清理（推荐先执行）
- `scripts/space-clean-deep.sh`: 深度清理（会更激进）
- `scripts/space-clean-flatpak.sh`: 清理 Flatpak 未使用运行时
- `scripts/space-clean-telegram.sh`: 清理 Telegram 缓存（不动 Spotify）
- `scripts/space-clean-downloads.sh`: 交互清理 Downloads 大文件
- `scripts/space-clean-mega.sh`: 可选卸载 `~/MEGA` 挂载

## 快速开始

```bash
cd /home/aerith/workspace/github/richang/archlinux
chmod +x scripts/*.sh
```

### 一键菜单（推荐）

```bash
./scripts/space-clean-menu.sh
```

菜单项说明：

- `1`: 空间检查
- `2`: 安全清理
- `3`: 深度清理
- `4`: Flatpak 清理（unused/runtime）
- `5`: Telegram 缓存清理（保留 Spotify）
- `6`: Downloads 大文件交互清理
- `7`: 卸载 MEGA 挂载（CloudDrive 不会触碰）

### 1) 先检查空间

```bash
./scripts/space-check.sh
```

### 2) 执行安全清理（推荐）

```bash
./scripts/space-clean-safe.sh
```

### 3) 空间仍然紧张时，再执行深度清理

```bash
./scripts/space-clean-deep.sh
```

## 脚本会处理哪些内容

### 安全清理

- 保留最近 2 个版本的 pacman 缓存，删除更旧缓存
- 删除“已卸载软件包”遗留缓存
- 清理 systemd journal（保留最近 14 天）
- 清空用户垃圾桶
- 清理 `~/.cache` 下常见缓存目录（浏览器、yay/paru 等）
- 尝试删除孤立依赖包（orphans）

### 深度清理（谨慎）

- 仅保留最近 1 个版本的 pacman 缓存
- 清空 pacman 全部包缓存（会导致以后重装/降级要重新下载）
- 将日志压缩到更小体积
- 激进清理用户缓存
- 如果安装了 Docker，额外执行 `docker system prune -af`

### 挂载盘（WebDAV/FUSE）保护

- 清理脚本会自动跳过“挂载点目录”，避免误删远端文件。
- `space-check.sh` 会显示 WebDAV/FUSE 挂载信息与 `davfs` 缓存占用。
- 如果你的挂载点恰好放在 `~/.cache` 下，也会被自动跳过。
- `space-clean-mega.sh` 只处理 `~/MEGA`，不会触碰 `~/CloudDrive`。

## 建议的使用频率（200G 分区）

- 每周：`space-check.sh`
- 每 2~4 周：`space-clean-safe.sh`
- 空间告急时：`space-clean-deep.sh`

## 手动排查大文件（可选）

```bash
sudo du -xh /var --max-depth=1 2>/dev/null | sort -h
du -xh ~ --max-depth=1 2>/dev/null | sort -h
```

## 注意事项

- 脚本会调用 `sudo`，请确保你的账号有 sudo 权限。
- 清理缓存后，某些软件首次启动会重新生成缓存，属于正常现象。
- 深度清理建议在网络良好时执行，避免后续安装软件时等待重新下载。
- 若想单独处理 WebDAV 缓存，可先查看 `space-check.sh` 中显示的 `davfs` 缓存体积再决定是否清理。
