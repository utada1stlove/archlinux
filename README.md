# Arch Linux Toolbox

This repository is a personal collection of Arch Linux utilities, scripts, and templates.
It includes disk cleanup helpers, CloudDrive auto-mount automation, Waydroid launcher tools,
a local VS Code syntax extension for `.dae` files, and LaTeX templates.

## Repository Layout

- `scripts/`: Arch Linux disk-space inspection and cleanup scripts
- `clouddrive-rclone/`: auto mount/unmount CloudDrive with rclone based on endpoint reachability
- `dae-vscode-syntax/`: local VS Code syntax extension for DAE config files
- `waydroid-launcher/`: menu-based Waydroid session and app launcher
- `latex/`: Chinese-oriented LaTeX templates and thesis material

## Quick Start

```bash
git clone git@github.com:utada1stlove/archlinux.git
cd archlinux
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

## 2) CloudDrive rclone Auto-Mount (`clouddrive-rclone/`)

This tool checks TCP reachability of a target endpoint.

- endpoint reachable -> mount CloudDrive
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
```

Optional systemd user timer files are provided in `clouddrive-rclone/systemd/`.

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

## 5) LaTeX Templates (`latex/`)

Template resources include:

- `latex/myself/`: Chinese book/report template (`ctexbook`, XeLaTeX)
- `latex/ultimate/`: extended personal template notes and example
- `latex/...2016.../`: Wuhan University master thesis template set

## Requirements

- Arch Linux (primary target)
- Bash
- `sudo` (for some cleanup actions)
- `rclone` (for CloudDrive auto-mount scripts)
- `waydroid` (for launcher scripts)
- VS Code (for DAE syntax extension)
- XeLaTeX distribution such as TeX Live (for LaTeX templates)

## Safety Notes

- Review scripts before running on production machines.
- Deep cleanup may remove caches that later need re-download.
- Cleanup scripts may invoke `sudo`.
- Keep a backup before applying aggressive cleanup or mount automation.
