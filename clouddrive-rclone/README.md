# CloudDrive Rclone Auto Mount

根据 `192.168.100.1:19798` 的 TCP 可达性自动挂载/卸载 `CloudDrive`。

- 连通 (`UP`) -> 自动挂载
- 不连通 (`DOWN`) -> 自动卸载

## 文件

- `clouddrive-autofs.sh`: 主脚本
- `config.env.example`: 配置模板
- `systemd/clouddrive-autofs.service`: systemd 用户服务（oneshot）
- `systemd/clouddrive-autofs.timer`: systemd 用户定时器

## 初始化

```bash
cd /home/aerith/archlinux/workshop/github/archlinux/clouddrive-rclone
cp config.env.example config.env
chmod +x clouddrive-autofs.sh
```

先确认 `config.env` 里的：

- `RCLONE_REMOTE`（你的 remote 名称）
- `MOUNT_POINT`（默认 `~/CloudDrive`）

## 手动运行

```bash
./clouddrive-autofs.sh status
./clouddrive-autofs.sh run-once
./clouddrive-autofs.sh watch
```

## 验证步骤（非常白话）

下面分两种情况：你现在不在家，和你回家后。

### A) 你现在不在家，也能验证（模拟环境）

这套验证不会碰你真实的 `~/CloudDrive`。

1. 进入目录

```bash
cd /home/aerith/archlinux/workshop/github/archlinux/clouddrive-rclone
```

2. 先创建测试配置（把挂载目录改成 `/tmp/CloudDrive-test`）

```bash
cat > config.test.env <<'EOF'
TARGET_HOST="127.0.0.1"
TARGET_PORT="19798"
RCLONE_REMOTE="/tmp"
MOUNT_POINT="/tmp/CloudDrive-test"
CHECK_INTERVAL_SEC="5"
CONNECT_TIMEOUT_SEC="1"
LOG_FILE="/tmp/rclone-clouddrive-test.log"
RCLONE_EXTRA_ARGS="--vfs-cache-mode off"
EOF
```

3. 模拟“在线”状态
意思是：假装 `127.0.0.1:19798` 可以连通。

```bash
nc -lk 127.0.0.1 19798 >/dev/null 2>&1 &
echo $! > /tmp/fake-cloudrive.pid
```

4. 跑一次自动逻辑（应该会挂载）

```bash
CLOUDRIVE_CONFIG=./config.test.env ./clouddrive-autofs.sh run-once
findmnt -T /tmp/CloudDrive-test
```

你看到有挂载信息，就说明“能连通就挂载”是正常的。

5. 模拟“离线”状态
意思是：把刚才假的端口服务关掉。

```bash
kill "$(cat /tmp/fake-cloudrive.pid)"
CLOUDRIVE_CONFIG=./config.test.env ./clouddrive-autofs.sh run-once
findmnt -T /tmp/CloudDrive-test || echo "已卸载"
```

出现 `已卸载`，就说明“不能连通就卸载”是正常的。

### B) 你回家后的真实验证（连你家路由）

1. 先看状态

```bash
./clouddrive-autofs.sh status
```

你应该能看到：
- 在家时通常是 `ENDPOINT=UP`
- 不在家通常是 `ENDPOINT=DOWN`

2. 跑一次自动逻辑

```bash
./clouddrive-autofs.sh run-once
```

3. 看 `CloudDrive` 是否真的挂上

```bash
findmnt -T ~/CloudDrive || echo "当前未挂载"
```

如果在家且远端服务正常，这里应该看到挂载信息。
如果不在家，这里应该是 `当前未挂载`。

## systemd 自动运行（推荐）

```bash
mkdir -p ~/.config/systemd/user
cp systemd/clouddrive-autofs.service ~/.config/systemd/user/
cp systemd/clouddrive-autofs.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now clouddrive-autofs.timer
```

查看状态：

```bash
systemctl --user status clouddrive-autofs.timer
journalctl --user -u clouddrive-autofs.service -f
```

## 说明

- 这是 TCP 检测（不是 ICMP ping）。因为你给的是 `ip:port`。
- 挂载目录已挂载但不是 rclone 类型时，脚本会跳过卸载，防止误操作。
