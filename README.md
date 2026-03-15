# Arch Linux Toolbox

This repository is a personal collection of Arch Linux utilities, scripts, and templates.
It includes disk cleanup helpers, CloudDrive auto-mount automation, Waydroid launcher tools,
a local VS Code syntax extension for `.dae` files, and LaTeX templates.

## Repository Layout

- `scripts/`: Arch Linux disk-space inspection and cleanup scripts
- `clouddrive-rclone/`: auto mount/unmount CloudDrive with rclone based on endpoint reachability
- `dae-vscode-syntax/`: local VS Code syntax extension for DAE config files
- `waydroid-launcher/`: menu-based Waydroid session and app launcher
- `adguard-cli-panel/`: menu-based AdGuard CLI control panel for Arch Linux
- `vnstat-arch/`: generate vnStat traffic images locally, then move to OneDrive after Insync starts
- `latex/`: Chinese-oriented LaTeX templates and thesis material
- `caddy-shortcuts/`: local domain shortcuts with Caddy (single imported routes file)
- `toolbox-panel.sh`: master interactive launcher for all major menu scripts
- `install-toolbox-command.sh`: install `toolbox` command into `~/.local/bin`

## Quick Start

```bash
git clone git@github.com:utada1stlove/archlinux.git
cd archlinux
chmod +x toolbox-panel.sh
./toolbox-panel.sh
./install-toolbox-command.sh
```

## 1) Disk Cleanup Scripts (`scripts/`)

Recommended entry:

```bash
chmod +x scripts/*.sh
./scripts/space-clean-menu.sh
```

Main scripts:

- `space-check.sh`: inspect disk usage and common cleanup targets
- `space-clean-safe.sh`: lower-risk cleanup (recommended regular run)
- `space-clean-deep.sh`: aggressive cleanup (use carefully)
- `space-clean-flatpak.sh`: remove unused Flatpak runtimes
- `space-clean-telegram.sh`: clear Telegram cache (keeps Spotify data)
- `space-clean-downloads.sh`: interactive cleanup for large files in `~/Downloads`
- `space-clean-mega.sh`: optional unmount cleanup for `~/MEGA`

Typical workflow:

```bash
./scripts/space-check.sh
./scripts/space-clean-safe.sh
# if still low on disk:
./scripts/space-clean-deep.sh
```

## 2) WebDAV rclone Auto-Mount (`clouddrive-rclone/`)

This tool checks TCP reachability of a target endpoint and then mounts/unmounts a WebDAV-style rclone remote.

- endpoint reachable -> mount remote
- endpoint unreachable -> unmount CloudDrive

Setup:

```bash
cd clouddrive-rclone
cp config.env.example config.env
chmod +x clouddrive-autofs.sh
```

Run:

```bash
./clouddrive-autofs.sh status
./clouddrive-autofs.sh run-once
./clouddrive-autofs.sh watch
./clouddrive-manager.sh
```

Optional systemd user timer files are provided in `clouddrive-rclone/systemd/`.
The manager now opens a `WebDAV` submenu with `clouddrive` and `openlist`, and extra profiles can live under `clouddrive-rclone/profiles/*.env`.

## 3) DAE VS Code Syntax Extension (`dae-vscode-syntax/`)

A local VS Code extension for highlighting `.dae` configuration files.

Install:

```bash
cd dae-vscode-syntax
chmod +x install-linux.sh
./install-linux.sh
```

Windows installation script is also included: `install-win.ps1`.

## 4) Waydroid Launcher (`waydroid-launcher/`)

Menu-based launcher for Arch Linux + Waydroid workflows:

- show status
- start/stop Waydroid session
- open full UI
- auto-discover installed apps and launch by package
- quick launch path for Legado (`com.legado.app.release` preferred)

Usage:

```bash
cd waydroid-launcher
chmod +x waydroid-menu.sh
./waydroid-menu.sh
```

## 5) vnStat Cache + Insync Move (`vnstat-arch/`)

This workflow is split into two scripts:

- Script A (`vnstat-generate-cache.sh`): run once after boot, generate `month/day/hour` images into `~/.cache/vnstat-arch/`
- Script B (`vnstat-move-after-insync.sh`): wait until `insync` process is running, then move cached images to OneDrive if target filename does not already exist

Systemd user unit files are included in `vnstat-arch/systemd/`.

Quick setup:

```bash
chmod +x vnstat-arch/*.sh
mkdir -p ~/.config/systemd/user
cp vnstat-arch/systemd/*.service ~/.config/systemd/user/
cp vnstat-arch/systemd/*.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now vnstat-arch-generate.timer
systemctl --user enable --now vnstat-arch-move-after-insync.timer
```

Details: see `vnstat-arch/README.md`.

## 6) AdGuard CLI Panel (`adguard-cli-panel/`)

Interactive panel for `adguard-cli` on Arch Linux:

- service control (`start/stop/restart/status`)
- config management
- custom user rules via `user.txt` (element hiding / exception / network blocking / import)
- log viewer for `app.log / proxy.log / access.log`, including recent `BLOCKED` entries and live follow
- filters / DNS filters / userscripts
- certificate generation and trust import helper
- license, update, import/export, speed test

Usage:

```bash
cd adguard-cli-panel
chmod +x adguard-panel.sh
./adguard-panel.sh
```

If `adguard-cli` is not in your `PATH`:

```bash
ADGUARD_BIN=/path/to/adguard-cli ./adguard-panel.sh
```

## 7) LaTeX Templates (`latex/`)

Template resources include:

- `latex/myself/`: Chinese book/report template (`ctexbook`, XeLaTeX)
- `latex/ultimate/`: extended personal template notes and example
- `latex/...2016.../`: Wuhan University master thesis template set

## 8) Caddy Local Shortcuts (`caddy-shortcuts/`)

Manage local shortcut domains with one imported routes file.

- Main config template: `caddy-shortcuts/Caddyfile.main`
- Single routes file: `caddy-shortcuts/shortcuts.caddy`
- Install script: `caddy-shortcuts/install.sh`
- Interactive panel: `caddy-shortcuts/shortcut-manager.sh`

Quick setup:

```bash
cd caddy-shortcuts
./install.sh
./shortcut-manager.sh
```

Note: `./install.sh` keeps existing `/etc/caddy/shortcuts.caddy` by default.
Use `./install.sh --reset-routes` only when you explicitly want template reset.

Default examples:

- `http://clouddrive.lan` -> reverse proxy `192.168.100.1:19798`
- `http://news.economist` -> redirect to `https://www.economist.com`

## 9) Master Panel (`toolbox-panel.sh`)

One entrypoint for major interactive scripts:

- Caddy shortcut panel
- WebDAV panel
- disk cleanup menu
- Waydroid menu
- AdGuard CLI panel

Run:

```bash
./toolbox-panel.sh
```

Install `toolbox` command (recommended):

```bash
./install-toolbox-command.sh
toolbox
```

If copied `toolbox-panel.sh` to another location:

```bash
ARCHLINUX_TOOLBOX_HOME=/path/to/archlinux ./toolbox-panel.sh
```

## Requirements

- Arch Linux (primary target)
- Bash
- `sudo` (for some cleanup actions)
- `rclone` (for CloudDrive auto-mount scripts)
- `waydroid` (for launcher scripts)
- `vnstat`/`vnstati` (for vnStat chart generation)
- `insync` (for delayed OneDrive move step)
- VS Code (for DAE syntax extension)
- XeLaTeX distribution such as TeX Live (for LaTeX templates)

## Safety Notes

- Review scripts before running on production machines.
- Deep cleanup may remove caches that later need re-download.
- Cleanup scripts may invoke `sudo`.
- Keep a backup before applying aggressive cleanup or mount automation.
