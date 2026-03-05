#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[1;36m'
COLOR_BLUE=$'\033[1;34m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_GREEN=$'\033[1;32m'

clear_screen() {
  printf '\033[2J\033[H'
}

print_banner() {
  cat <<EOF
${COLOR_CYAN} ____                  ____ _                         ${COLOR_RESET}
${COLOR_CYAN}/ ___| _ __   __ _  ___/ ___| | ___  __ _ _ __        ${COLOR_RESET}
${COLOR_CYAN}\___ \| '_ \ / _\` |/ __| |   | |/ _ \/ _\` | '_ \       ${COLOR_RESET}
${COLOR_CYAN} ___) | |_) | (_| | (__| |___| |  __/ (_| | | | |      ${COLOR_RESET}
${COLOR_CYAN}|____/| .__/ \__,_|\___|\____|_|\___|\__,_|_| |_|      ${COLOR_RESET}
${COLOR_CYAN}      |_|                                              ${COLOR_RESET}
${COLOR_BLUE}======================== Space Cleanup Panel ========================${COLOR_RESET}
EOF
}

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
    clear_screen
    print_banner
    show_menu
    read -r -p "请输入数字并回车: " choice

    case "$choice" in
      1)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：空间检查${COLOR_RESET}"
        run_script "space-check.sh"
        ;;
      2)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：安全清理${COLOR_RESET}"
        run_script "space-clean-safe.sh"
        ;;
      3)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：深度清理${COLOR_RESET}"
        run_script "space-clean-deep.sh"
        ;;
      4)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：Flatpak 清理${COLOR_RESET}"
        run_script "space-clean-flatpak.sh"
        ;;
      5)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：Telegram 缓存清理${COLOR_RESET}"
        run_script "space-clean-telegram.sh"
        ;;
      6)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：Downloads 清理${COLOR_RESET}"
        run_script "space-clean-downloads.sh"
        ;;
      7)
        clear_screen
        print_banner
        echo -e "${COLOR_YELLOW}执行：卸载 MEGA 挂载${COLOR_RESET}"
        run_script "space-clean-mega.sh"
        ;;
      0)
        clear_screen
        print_banner
        echo -e "${COLOR_GREEN}已退出。${COLOR_RESET}"
        exit 0
        ;;
      *)
        echo "无效输入，请输入 0-7。"
        ;;
    esac
  done
}

main "$@"
