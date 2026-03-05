# vnstat-arch

Generate vnStat charts into a local cache at boot, then move them to Insync OneDrive
only after Insync starts.

## What It Does

- Script A (`vnstat-generate-cache.sh`) runs once after boot and generates from interface `wlan0`:
  - `monthYY-MM.png`
  - `dayYY-MM-DD.png`
  - `hourYY-MM-DD-HH.png`
- Files are written to `~/.cache/vnstat-arch/` first.
- If a same-name file already exists in cache, generation is skipped.

- Script B (`vnstat-move-after-insync.sh`) runs once after boot, waits for `insync` process,
  then moves files from cache to:
  - `/home/aerith/Insync/innovationqvq@hotmail.com/OneDrive/vnstat-arch/`
- If target has same-name file, it is skipped (no overwrite, no move).

## Requirements

- `vnstat` with `vnstati`
- `insync`
- `systemd --user`

## Install (systemd user)

```bash
cd ~/archlinux/workshop/github/archlinux
chmod +x vnstat-arch/*.sh

mkdir -p ~/.config/systemd/user
cp vnstat-arch/systemd/vnstat-arch-generate.service ~/.config/systemd/user/
cp vnstat-arch/systemd/vnstat-arch-generate.timer ~/.config/systemd/user/
cp vnstat-arch/systemd/vnstat-arch-move-after-insync.service ~/.config/systemd/user/
cp vnstat-arch/systemd/vnstat-arch-move-after-insync.timer ~/.config/systemd/user/

systemctl --user daemon-reload
systemctl --user enable --now vnstat-arch-generate.timer
systemctl --user enable --now vnstat-arch-move-after-insync.timer
```

## Manual Test

```bash
# A: generate to cache
./vnstat-arch/vnstat-generate-cache.sh

# B: wait insync then move to OneDrive
./vnstat-arch/vnstat-move-after-insync.sh
```

## Optional Environment Overrides

- `VNSTAT_IFACE` (default: `wlan0`)
- `VNSTAT_CACHE_DIR` (default: `~/.cache/vnstat-arch`)
- `VNSTAT_TARGET_DIR` (default: `/home/aerith/Insync/innovationqvq@hotmail.com/OneDrive/vnstat-arch`)
- `INSYNC_WAIT_TIMEOUT_SEC` (default: `1800`)
- `INSYNC_POLL_INTERVAL_SEC` (default: `5`)
