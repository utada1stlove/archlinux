# AdGuard CLI Panel

Arch Linux 上的 `adguard-cli` 交互脚本面板，适合把常用操作做成数字菜单。

功能覆盖：

- 服务控制：`start / stop / restart / status / configure`
- 配置管理：`config show/get/set/list-add/list-remove/reset`
- 自定义规则：直接管理 `user.txt`，快速新增元素隐藏/例外/网络拦截规则，并可导入外部规则文件
- 日志查看：直接读取 `app.log / proxy.log / access.log`，支持查看最近 `BLOCKED` 记录、关键字搜索和实时跟踪
- 过滤器管理：`filters` 与 `dns filters`
- Userscripts 管理
- 证书辅助：生成证书、列出 Firefox profile、本地证书查看、导入系统信任库
- 更新与许可证
- 设置/日志导入导出
- `speed` 性能测试

运行：

```bash
cd archlinux/adguard-cli-panel
chmod +x adguard-panel.sh
./adguard-panel.sh
```

如果 `adguard-cli` 不在默认 `PATH`：

```bash
ADGUARD_BIN=/custom/path/adguard-cli ./adguard-panel.sh
./adguard-panel.sh --bin /custom/path/adguard-cli
```

说明：

- 证书导入系统信任库会调用 `sudo` 与 `trust extract-compat`
- Firefox 若要信任系统证书，通常还要确认 `about:config` 中 `security.enterprise_roots.enabled=true`
- 本脚本也已经接入 [`toolbox-panel.sh`](/home/aerith/archlinux/workshop/github/archlinux/toolbox-panel.sh)
