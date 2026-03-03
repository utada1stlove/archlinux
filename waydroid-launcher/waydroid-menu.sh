#!/usr/bin/env bash
set -euo pipefail

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

is_session_running() {
  waydroid status 2>/dev/null | grep -qE '^Session:[[:space:]]*RUNNING'
}

show_status() {
  echo
  echo "== Waydroid Status =="
  waydroid status 2>/dev/null || echo "Unable to read waydroid status."
}

start_session() {
  if is_session_running; then
    echo "Waydroid session is already running."
    return 0
  fi

  echo "Starting Waydroid session..."
  local output
  output="$(waydroid session start 2>&1 || true)"
  sleep 1

  if is_session_running; then
    echo "Waydroid session started."
  else
    echo "Failed to start Waydroid session."
    [[ -n "$output" ]] && echo "$output"
  fi
}

stop_session() {
  if ! is_session_running; then
    echo "Waydroid session is already stopped."
    return 0
  fi

  echo "Stopping Waydroid session..."
  local output
  output="$(waydroid session stop 2>&1 || true)"
  sleep 1

  if is_session_running; then
    echo "Failed to stop Waydroid session."
    [[ -n "$output" ]] && echo "$output"
  else
    echo "Waydroid session stopped."
  fi
}

show_full_ui() {
  if ! is_session_running; then
    echo "Waydroid session is stopped. Starting first..."
    start_session
  fi

  if ! is_session_running; then
    return 1
  fi

  echo "Opening Waydroid full UI..."
  waydroid show-full-ui
}

discover_apps() {
  local output

  if ! is_session_running; then
    echo "Waydroid session is stopped. Please start session first."
    return 1
  fi

  output="$(waydroid app list 2>&1 || true)"

  if echo "$output" | grep -qi "WayDroid session is stopped"; then
    echo "Waydroid session is stopped."
    return 1
  fi

  mapfile -t APP_ROWS < <(
    printf '%s\n' "$output" | awk -F': ' '
      /^Name: / { name=$2 }
      /^packageName: / {
        pkg=$2
        if (name != "" && pkg != "") {
          print name "\t" pkg
        }
      }
    '
  )

  if [[ "${#APP_ROWS[@]}" -eq 0 ]]; then
    echo "No apps discovered."
    return 1
  fi

  return 0
}

launch_by_package() {
  local pkg="$1"
  if [[ -z "$pkg" ]]; then
    echo "Empty package name."
    return 1
  fi

  if ! is_session_running; then
    echo "Waydroid session is stopped. Starting first..."
    start_session
  fi

  if ! is_session_running; then
    return 1
  fi

  echo "Launching: $pkg"
  waydroid app launch "$pkg"
}

launch_app_menu() {
  local choice index name pkg

  while true; do
    echo
    echo "== Detecting Waydroid apps =="
    if ! discover_apps; then
      echo "Press Enter to return..."
      read -r
      return 0
    fi

    for index in "${!APP_ROWS[@]}"; do
      name="${APP_ROWS[$index]%%$'\t'*}"
      pkg="${APP_ROWS[$index]#*$'\t'}"
      printf "%2d) %s (%s)\n" "$((index + 1))" "$name" "$pkg"
    done

    echo "m) 手动输入包名启动"
    echo "r) 刷新应用列表"
    echo "0) 返回主菜单"
    read -r -p "请选择应用: " choice

    case "$choice" in
      0)
        return 0
        ;;
      r|R)
        continue
        ;;
      m|M)
        read -r -p "请输入 packageName: " pkg
        launch_by_package "$pkg"
        ;;
      *)
        if [[ "$choice" =~ ^[0-9]+$ ]]; then
          if (( choice >= 1 && choice <= ${#APP_ROWS[@]} )); then
            pkg="${APP_ROWS[$((choice - 1))]#*$'\t'}"
            launch_by_package "$pkg"
          else
            echo "Invalid app index."
          fi
        else
          echo "Invalid input."
        fi
        ;;
    esac
  done
}

quick_launch_legado() {
  local row name pkg lname lpkg
  local -a candidates=(
    "com.legado.app.release"
    "io.legado.app.release"
    "io.legado.app"
    "io.legado.app.beta"
    "cn.reader"
  )

  if ! is_session_running; then
    echo "Waydroid session is stopped. Starting first..."
    start_session
  fi

  if ! is_session_running; then
    return 1
  fi

  # 1) Prefer installed app list match (supports typo alias ledago/legado)
  if discover_apps; then
    for row in "${APP_ROWS[@]}"; do
      name="${row%%$'\t'*}"
      pkg="${row#*$'\t'}"
      lname="$(echo "$name" | tr '[:upper:]' '[:lower:]')"
      lpkg="$(echo "$pkg" | tr '[:upper:]' '[:lower:]')"

      if [[ "$lname" == *legado* || "$lname" == *ledago* || "$name" == *阅读* \
         || "$lpkg" == *legado* || "$lpkg" == *ledago* ]]; then
        echo "Matched Legado app: $name ($pkg)"
        launch_by_package "$pkg"
        return $?
      fi
    done
  fi

  # 2) Fallback known package names
  for pkg in "${candidates[@]}"; do
    echo "Trying package: $pkg"
    if waydroid app launch "$pkg" >/dev/null 2>&1; then
      echo "Launched: $pkg"
      return 0
    fi
  done

  echo "Legado not found automatically."
  echo "Use option 4 -> m to input packageName manually."
  return 1
}

show_menu() {
  cat <<'MENU'

==============================
 Waydroid 数字启动菜单
==============================
1) 查看状态
2) 启动 Waydroid Session
3) 启动 Full UI
4) 检测并启动应用
5) 停止 Waydroid Session
6) 快速启动 Legado / ledago
0) 退出
MENU
}

main() {
  local choice
  require_cmd waydroid

  while true; do
    show_menu
    read -r -p "请输入数字并回车: " choice

    case "$choice" in
      1)
        show_status
        ;;
      2)
        start_session
        ;;
      3)
        show_full_ui
        ;;
      4)
        launch_app_menu
        ;;
      5)
        stop_session
        ;;
      6)
        quick_launch_legado
        ;;
      0)
        echo "Bye."
        exit 0
        ;;
      *)
        echo "无效输入，请输入 0-6。"
        ;;
    esac
  done
}

APP_ROWS=()
main "$@"
