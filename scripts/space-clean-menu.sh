#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_script() {
  local script_name="$1"
  local script_path="$SCRIPT_DIR/$script_name"
  if [[ ! -x "$script_path" ]]; then
    echo "Script not executable or missing: $script_path"
    return 1
  fi
  "$script_path"
}

show_menu() {
  cat <<'EOF'

==============================
 Arch Linux 空间清理菜单
==============================
1) 空间检查（推荐先执行）
2) 安全清理（常规）
3) 深度清理（谨慎）
4) Flatpak 清理（unused/runtime）
5) Telegram 缓存清理（保留 Spotify）
6) Downloads 大文件交互清理
7) 卸载 MEGA 挂载（可选）
0) 退出
EOF
}

main() {
  while true; do
    show_menu
    read -r -p "请输入数字并回车: " choice

    case "$choice" in
      1)
        run_script "space-check.sh"
        ;;
      2)
        run_script "space-clean-safe.sh"
        ;;
      3)
        run_script "space-clean-deep.sh"
        ;;
      4)
        run_script "space-clean-flatpak.sh"
        ;;
      5)
        run_script "space-clean-telegram.sh"
        ;;
      6)
        run_script "space-clean-downloads.sh"
        ;;
      7)
        run_script "space-clean-mega.sh"
        ;;
      0)
        echo "已退出。"
        exit 0
        ;;
      *)
        echo "无效输入，请输入 0-7。"
        ;;
    esac
  done
}

main "$@"
