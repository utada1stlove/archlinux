# Waydroid Launcher

用于 Arch Linux 的 Waydroid 数字菜单启动脚本。

## 文件

- `waydroid-menu.sh`: 数字菜单，支持状态查看、启动 Session、启动 Full UI、自动检测应用并启动。
- 内置 `Legado/ledago` 快速启动入口（自动匹配名称或包名）。

## 使用

```bash
cd /home/aerith/archlinux/workshop/github/archlinux/waydroid-launcher
chmod +x waydroid-menu.sh
./waydroid-menu.sh
```

菜单新增：

- `6) 快速启动 Legado / ledago`

## 应用检测说明

脚本会通过 `waydroid app list` 自动读取应用列表。
解析规则使用 Waydroid 原生输出中的：

- `Name: ...`
- `packageName: ...`

如果当时只安装了 Legado（阅读），菜单里会只显示这一个应用。

已确认可用包名：`com.legado.app.release`（菜单 6 会优先尝试该包名）。
