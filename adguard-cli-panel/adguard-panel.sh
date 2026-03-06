#!/usr/bin/env bash
set -euo pipefail

COLOR_RESET=$'\033[0m'
COLOR_CYAN=$'\033[1;36m'
COLOR_BLUE=$'\033[1;34m'
COLOR_YELLOW=$'\033[1;33m'
COLOR_GREEN=$'\033[1;32m'
COLOR_RED=$'\033[1;31m'
UTF8_BOM=$'\xef\xbb\xbf'

ADGUARD_BIN="${ADGUARD_BIN:-}"
ADGUARD_HOME="${ADGUARD_HOME:-$HOME/.local/share/adguard-cli}"
USER_RULES_FILE="${ADGUARD_USER_RULES_FILE:-$ADGUARD_HOME/user.txt}"
LOGS_DIR="${ADGUARD_LOGS_DIR:-$ADGUARD_HOME/logs}"
APP_LOG_FILE="$LOGS_DIR/app.log"
PROXY_LOG_FILE="$LOGS_DIR/proxy.log"
ACCESS_LOG_FILE="$LOGS_DIR/access.log"
DEFAULT_LOG_TAIL_LINES="${ADGUARD_LOG_TAIL_LINES:-60}"

clear_screen() {
  printf '\033[2J\033[H'
}

pause() {
  echo
  read -r -p "按 Enter 返回..." _
}

usage() {
  cat <<'EOF'
Usage: ./adguard-panel.sh [--bin /path/to/adguard-cli]

Environment:
  ADGUARD_BIN   Path to the adguard-cli binary.
  ADGUARD_HOME  AdGuard CLI data directory.
  ADGUARD_USER_RULES_FILE   Path to the user rules file.
  ADGUARD_LOGS_DIR   Path to the AdGuard CLI logs directory.
  ADGUARD_LOG_TAIL_LINES   Default lines shown in log views.
EOF
}

cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

resolve_adguard_bin() {
  local detected

  if [[ -n "$ADGUARD_BIN" && -x "$ADGUARD_BIN" ]]; then
    return 0
  fi

  detected="$(command -v adguard-cli 2>/dev/null || true)"
  if [[ -n "$detected" ]]; then
    ADGUARD_BIN="$detected"
    return 0
  fi

  return 1
}

require_adguard_bin() {
  if resolve_adguard_bin; then
    return 0
  fi

  echo "adguard-cli 未安装或不在 PATH 中。"
  echo "Arch Linux 可先尝试：yay -S adguard-cli-bin"
  return 1
}

strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[[:alpha:]]//g'
}

get_adguard_version() {
  local version

  version="$("$ADGUARD_BIN" --version 2>/dev/null || "$ADGUARD_BIN" -v 2>/dev/null || true)"
  if [[ -n "$version" ]]; then
    printf '%s\n' "$version"
  else
    printf '%s\n' "unknown"
  fi
}

status_overview() {
  local output clean first_line auto_line

  output="$("$ADGUARD_BIN" status 2>&1 || true)"
  clean="$(printf '%s\n' "$output" | strip_ansi)"
  first_line="$(printf '%s\n' "$clean" | sed -n '1p')"
  auto_line="$(printf '%s\n' "$clean" | grep -i 'automatic filtering' | head -n 1 || true)"

  if [[ -z "$first_line" ]]; then
    first_line="status unavailable"
  fi

  printf '%s\n' "$first_line"
  if [[ -n "$auto_line" && "$auto_line" != "$first_line" ]]; then
    printf '%s\n' "$auto_line"
  fi
}

print_banner() {
  local version
  local -a status_lines=()

  version="$(get_adguard_version)"
  mapfile -t status_lines < <(status_overview)

  cat <<EOF
${COLOR_CYAN}    _    ____   ____                     _ ${COLOR_RESET}
${COLOR_CYAN}   / \  |  _ \ / ___|_   _  __ _ _ __ __| |${COLOR_RESET}
${COLOR_CYAN}  / _ \ | | | | |  _| | | |/ _\` | '__/ _\` |${COLOR_RESET}
${COLOR_CYAN} / ___ \| |_| | |_| | |_| | (_| | | | (_| |${COLOR_RESET}
${COLOR_CYAN}/_/   \_\____/ \____|\__,_|\__,_|_|  \__,_|${COLOR_RESET}
${COLOR_BLUE}======================== AdGuard CLI Control Panel ========================${COLOR_RESET}
EOF
  echo -e "${COLOR_YELLOW}Binary:${COLOR_RESET} ${ADGUARD_BIN}"
  echo -e "${COLOR_YELLOW}Version:${COLOR_RESET} ${version}"
  if [[ "${#status_lines[@]}" -ge 1 ]]; then
    echo -e "${COLOR_YELLOW}Status:${COLOR_RESET} ${status_lines[0]}"
  fi
  if [[ "${#status_lines[@]}" -ge 2 ]]; then
    echo -e "${COLOR_YELLOW}Mode:${COLOR_RESET} ${status_lines[1]}"
  fi
  echo
}

confirm_action() {
  local prompt="$1"
  local answer

  read -r -p "$prompt" answer || return 1
  case "$answer" in
    y|Y|yes|YES|Yes|是)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

prompt_nonempty() {
  local prompt="$1"
  local value

  while true; do
    read -r -p "$prompt" value || return 1
    if [[ -n "$value" ]]; then
      printf '%s\n' "$value"
      return 0
    fi
    echo "输入不能为空。"
  done
}

prompt_positive_integer() {
  local prompt="$1"
  local default_value="$2"
  local value

  while true; do
    read -r -p "${prompt} [默认: ${default_value}]: " value || return 1
    value="${value:-$default_value}"
    if [[ "$value" =~ ^[1-9][0-9]*$ ]]; then
      printf '%s\n' "$value"
      return 0
    fi
    echo "请输入大于 0 的整数。" >&2
  done
}

default_export_path() {
  if [[ -d "$HOME/Downloads" ]]; then
    printf '%s\n' "$HOME/Downloads"
  else
    printf '%s\n' "$HOME"
  fi
}

ensure_user_rules_file() {
  mkdir -p "$(dirname "$USER_RULES_FILE")"
  if [[ ! -s "$USER_RULES_FILE" ]]; then
    printf '%s\n' '! User filter' > "$USER_RULES_FILE"
  fi
}

require_log_file() {
  local title="$1"
  local file="$2"

  if [[ -f "$file" ]]; then
    return 0
  fi

  clear_screen
  print_banner
  echo -e "${COLOR_RED}${title}${COLOR_RESET}"
  echo
  echo "未找到日志文件: $file"
  pause
  return 1
}

show_logs_overview() {
  local file label size modified
  local -a labels=("app.log" "proxy.log" "access.log")
  local -a files=("$APP_LOG_FILE" "$PROXY_LOG_FILE" "$ACCESS_LOG_FILE")

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}日志目录概览${COLOR_RESET}"
  echo "日志目录: $LOGS_DIR"
  echo

  if [[ ! -d "$LOGS_DIR" ]]; then
    echo "未找到日志目录。"
    pause
    return 0
  fi

  for i in "${!files[@]}"; do
    label="${labels[$i]}"
    file="${files[$i]}"
    echo "${label}:"
    echo "  路径: $file"
    if [[ -f "$file" ]]; then
      size="$(stat -c '%s' "$file" 2>/dev/null || printf '%s' '?')"
      modified="$(stat -c '%y' "$file" 2>/dev/null | cut -d'.' -f1 || printf '%s' 'unknown')"
      echo "  大小: ${size} bytes"
      echo "  更新: $modified"
    else
      echo "  状态: 未找到"
    fi
    echo
  done
  pause
}

show_log_tail() {
  local title="$1"
  local file="$2"
  local lines

  if ! require_log_file "$title" "$file"; then
    return 0
  fi

  if ! lines="$(prompt_positive_integer "显示多少行" "$DEFAULT_LOG_TAIL_LINES")"; then
    pause
    return 0
  fi

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}${title}${COLOR_RESET}"
  echo "文件路径: $file"
  echo "显示行数: $lines"
  echo
  tail -n "$lines" "$file"
  pause
}

show_recent_blocked_requests() {
  local lines tmp_file total

  if ! require_log_file "查看屏蔽日志" "$ACCESS_LOG_FILE"; then
    return 0
  fi

  if ! lines="$(prompt_positive_integer "显示多少条 BLOCKED 记录" "$DEFAULT_LOG_TAIL_LINES")"; then
    pause
    return 0
  fi

  tmp_file="$(mktemp)"
  awk '/ BLOCKED / { print }' "$ACCESS_LOG_FILE" > "$tmp_file"

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}最近屏蔽日志（access.log）${COLOR_RESET}"
  echo "文件路径: $ACCESS_LOG_FILE"
  echo

  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    echo "暂无 BLOCKED 记录。"
    pause
    return 0
  fi

  total="$(wc -l < "$tmp_file")"
  echo "BLOCKED 总数: $total"
  echo "显示最后: $lines"
  echo
  tail -n "$lines" "$tmp_file"
  rm -f "$tmp_file"
  pause
}

search_log_by_keyword() {
  local title="$1"
  local file="$2"
  local only_blocked="${3:-false}"
  local keyword lines tmp_file total

  if ! require_log_file "$title" "$file"; then
    return 0
  fi

  if ! keyword="$(prompt_nonempty "请输入关键字（按原样匹配）: ")"; then
    pause
    return 0
  fi
  if ! lines="$(prompt_positive_integer "最多显示多少条匹配" "$DEFAULT_LOG_TAIL_LINES")"; then
    pause
    return 0
  fi

  tmp_file="$(mktemp)"
  if [[ "$only_blocked" == "true" ]]; then
    awk -v needle="$keyword" '/ BLOCKED / && index($0, needle) { print }' "$file" > "$tmp_file"
  else
    awk -v needle="$keyword" 'index($0, needle) { print }' "$file" > "$tmp_file"
  fi

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}${title}${COLOR_RESET}"
  echo "文件路径: $file"
  echo "关键字: $keyword"
  echo

  if [[ ! -s "$tmp_file" ]]; then
    rm -f "$tmp_file"
    echo "没有匹配记录。"
    pause
    return 0
  fi

  total="$(wc -l < "$tmp_file")"
  echo "匹配总数: $total"
  echo "显示最后: $lines"
  echo
  tail -n "$lines" "$tmp_file"
  rm -f "$tmp_file"
  pause
}

follow_log_file() {
  local title="$1"
  local file="$2"
  local rc

  if ! require_log_file "$title" "$file"; then
    return 0
  fi

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}${title}${COLOR_RESET}"
  echo "文件路径: $file"
  echo "按 Ctrl+C 停止跟踪并返回。"
  echo

  set +e
  tail -n 20 -F "$file"
  rc=$?
  set -e

  echo
  if [[ "$rc" -ne 0 && "$rc" -ne 130 ]]; then
    echo -e "${COLOR_RED}日志跟踪异常结束，退出码: $rc${COLOR_RESET}"
  else
    echo "已停止跟踪。"
  fi
  pause
}

follow_blocked_requests() {
  local rc

  if ! require_log_file "实时跟踪屏蔽日志" "$ACCESS_LOG_FILE"; then
    return 0
  fi

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}实时跟踪屏蔽日志（access.log）${COLOR_RESET}"
  echo "文件路径: $ACCESS_LOG_FILE"
  echo "按 Ctrl+C 停止跟踪并返回。"
  echo

  set +e
  tail -n 20 -F "$ACCESS_LOG_FILE" | awk '/ BLOCKED / { print; fflush() }'
  rc=$?
  set -e

  echo
  if [[ "$rc" -ne 0 && "$rc" -ne 130 ]]; then
    echo -e "${COLOR_RED}屏蔽日志跟踪异常结束，退出码: $rc${COLOR_RESET}"
  else
    echo "已停止跟踪。"
  fi
  pause
}

adguard_is_running() {
  local output

  output="$("$ADGUARD_BIN" status 2>&1 || true)"
  output="$(printf '%s\n' "$output" | strip_ansi)"
  printf '%s\n' "$output" | grep -qi 'proxy server is running'
}

restart_after_user_rules_change() {
  local rc

  if ! adguard_is_running; then
    echo "规则已保存，但 AdGuard 当前未运行。"
    echo "稍后执行 adguard-cli start 或 adguard-cli restart 即可加载新规则。"
    return 0
  fi

  echo
  echo "正在重启 AdGuard 以加载新规则..."
  set +e
  "$ADGUARD_BIN" restart
  rc=$?
  set -e

  if [[ "$rc" -eq 0 ]]; then
    echo -e "${COLOR_GREEN}AdGuard 已重启，新规则已生效。${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}AdGuard 重启失败，请稍后手动执行 adguard-cli restart。${COLOR_RESET}"
  fi
  return 0
}

append_user_rule_line() {
  local rule="$1"

  ensure_user_rules_file
  if grep -Fxq -- "$rule" "$USER_RULES_FILE"; then
    return 2
  fi

  printf '%s\n' "$rule" >> "$USER_RULES_FILE"
}

backup_user_rules_file() {
  local ts backup_file

  ensure_user_rules_file
  ts="$(date '+%Y%m%d-%H%M%S')"
  backup_file="${USER_RULES_FILE}.bak-${ts}"
  cp "$USER_RULES_FILE" "$backup_file"
  printf '%s\n' "$backup_file"
}

show_user_rules_file() {
  ensure_user_rules_file

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}当前 user.txt 规则${COLOR_RESET}"
  echo "文件路径: $USER_RULES_FILE"
  echo
  nl -ba "$USER_RULES_FILE"
  pause
}

show_user_rule_examples() {
  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}常用自定义规则示例${COLOR_RESET}"
  echo
  cat <<'EOF'
example.com##.sidebar-ad
  隐藏 example.com 上 class 为 sidebar-ad 的元素

##.global-popup
  全局隐藏 class 为 global-popup 的元素

example.com#@#.sidebar-ad
  在 example.com 上取消隐藏 .sidebar-ad

||ads.example.com^
  拦截整个广告子域名

||example.com/banner.js
  拦截某个具体脚本或资源 URL

! 这是注释
  注释行以 ! 开头，不参与过滤
EOF
  pause
}

save_user_rule() {
  local title="$1"
  local rule="$2"
  local append_rc

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}${title}${COLOR_RESET}"
  echo
  echo "规则预览:"
  echo "$rule"
  echo
  echo "写入文件: $USER_RULES_FILE"
  echo

  if ! confirm_action "确认写入? [y/N]: "; then
    echo "已取消。"
    pause
    return 0
  fi

  set +e
  append_user_rule_line "$rule"
  append_rc=$?
  set -e

  case "$append_rc" in
    0)
      echo
      echo -e "${COLOR_GREEN}规则已写入。${COLOR_RESET}"
      restart_after_user_rules_change
      ;;
    2)
      echo
      echo -e "${COLOR_YELLOW}规则已存在，未重复写入。${COLOR_RESET}"
      ;;
    *)
      echo
      echo -e "${COLOR_RED}写入失败。${COLOR_RESET}"
      ;;
  esac
  pause
}

add_cosmetic_hide_rule() {
  local scope selector rule

  read -r -p "作用域域名 [留空=全局，例如 example.com]: " scope || {
    pause
    return 0
  }
  if ! selector="$(prompt_nonempty "请输入 CSS 选择器: ")"; then
    pause
    return 0
  fi

  if [[ -n "$scope" ]]; then
    rule="${scope}##${selector}"
  else
    rule="##${selector}"
  fi

  save_user_rule "新增元素隐藏规则" "$rule"
}

add_cosmetic_exception_rule() {
  local scope selector rule

  read -r -p "作用域域名 [留空=全局，例如 example.com]: " scope || {
    pause
    return 0
  }
  if ! selector="$(prompt_nonempty "请输入 CSS 选择器: ")"; then
    pause
    return 0
  fi

  if [[ -n "$scope" ]]; then
    rule="${scope}#@#${selector}"
  else
    rule="#@#${selector}"
  fi

  save_user_rule "新增元素例外规则" "$rule"
}

add_network_block_rule() {
  local rule

  if ! rule="$(prompt_nonempty "请输入完整网络拦截规则: ")"; then
    pause
    return 0
  fi

  save_user_rule "新增网络拦截规则" "$rule"
}

add_user_rule_comment() {
  local comment

  if ! comment="$(prompt_nonempty "请输入注释内容: ")"; then
    pause
    return 0
  fi

  save_user_rule "新增注释" "! ${comment}"
}

delete_user_rule_line() {
  local line total current_line tmp_file

  ensure_user_rules_file

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}删除指定 user.txt 行${COLOR_RESET}"
  echo "文件路径: $USER_RULES_FILE"
  echo
  nl -ba "$USER_RULES_FILE"
  echo

  read -r -p "请输入要删除的行号: " line
  if [[ ! "$line" =~ ^[0-9]+$ ]]; then
    echo "请输入数字行号。"
    pause
    return 0
  fi

  total="$(wc -l < "$USER_RULES_FILE")"
  if (( line < 1 || line > total )); then
    echo "行号超出范围。"
    pause
    return 0
  fi

  current_line="$(sed -n "${line}p" "$USER_RULES_FILE")"
  echo
  echo "即将删除:"
  echo "$current_line"
  echo

  if ! confirm_action "确认删除第 ${line} 行? [y/N]: "; then
    echo "已取消。"
    pause
    return 0
  fi

  tmp_file="$(mktemp)"
  sed "${line}d" "$USER_RULES_FILE" > "$tmp_file"
  mv "$tmp_file" "$USER_RULES_FILE"

  if [[ ! -s "$USER_RULES_FILE" ]]; then
    printf '%s\n' '! User filter' > "$USER_RULES_FILE"
  fi

  echo
  echo -e "${COLOR_GREEN}已删除。${COLOR_RESET}"
  restart_after_user_rules_change
  pause
}

import_user_rules_append() {
  local source_path tmp_file backup_file line imported=0 duplicates=0 skipped=0

  if ! source_path="$(prompt_nonempty "请输入外部规则文件路径: ")"; then
    pause
    return 0
  fi

  if [[ ! -f "$source_path" ]]; then
    echo "文件不存在: $source_path"
    pause
    return 0
  fi

  ensure_user_rules_file
  tmp_file="$(mktemp)"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"$UTF8_BOM"}"

    if [[ -z "${line//[[:space:]]/}" ]]; then
      ((skipped += 1))
      continue
    fi
    if [[ "$line" == '! User filter' ]]; then
      ((skipped += 1))
      continue
    fi
    if grep -Fxq -- "$line" "$USER_RULES_FILE" || grep -Fxq -- "$line" "$tmp_file"; then
      ((duplicates += 1))
      continue
    fi

    printf '%s\n' "$line" >> "$tmp_file"
    ((imported += 1))
  done < "$source_path"

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}追加导入用户规则${COLOR_RESET}"
  echo
  echo "来源文件: $source_path"
  echo "目标文件: $USER_RULES_FILE"
  echo "可追加规则数: $imported"
  echo "重复规则数: $duplicates"
  echo "跳过空行/头部: $skipped"
  echo

  if (( imported == 0 )); then
    rm -f "$tmp_file"
    echo "没有可导入的新规则。"
    pause
    return 0
  fi

  if ! confirm_action "确认追加导入这些规则? [y/N]: "; then
    rm -f "$tmp_file"
    echo "已取消。"
    pause
    return 0
  fi

  backup_file="$(backup_user_rules_file)"
  cat "$tmp_file" >> "$USER_RULES_FILE"
  rm -f "$tmp_file"

  echo
  echo -e "${COLOR_GREEN}规则已追加导入。${COLOR_RESET}"
  echo "备份文件: $backup_file"
  restart_after_user_rules_change
  pause
}

import_user_rules_replace() {
  local source_path tmp_file backup_file line imported=0 duplicates=0 skipped=0

  if ! source_path="$(prompt_nonempty "请输入外部规则文件路径: ")"; then
    pause
    return 0
  fi

  if [[ ! -f "$source_path" ]]; then
    echo "文件不存在: $source_path"
    pause
    return 0
  fi

  tmp_file="$(mktemp)"
  printf '%s\n' '! User filter' > "$tmp_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%$'\r'}"
    line="${line#"$UTF8_BOM"}"

    if [[ -z "${line//[[:space:]]/}" ]]; then
      ((skipped += 1))
      continue
    fi
    if [[ "$line" == '! User filter' ]]; then
      ((skipped += 1))
      continue
    fi
    if grep -Fxq -- "$line" "$tmp_file"; then
      ((duplicates += 1))
      continue
    fi

    printf '%s\n' "$line" >> "$tmp_file"
    ((imported += 1))
  done < "$source_path"

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}覆盖导入用户规则${COLOR_RESET}"
  echo
  echo "来源文件: $source_path"
  echo "目标文件: $USER_RULES_FILE"
  echo "将导入规则数: $imported"
  echo "来源文件内重复规则数: $duplicates"
  echo "跳过空行/头部: $skipped"
  echo
  echo -e "${COLOR_RED}这会覆盖当前 user.txt。${COLOR_RESET}"
  echo

  if ! confirm_action "确认覆盖导入? [y/N]: "; then
    rm -f "$tmp_file"
    echo "已取消。"
    pause
    return 0
  fi

  backup_file="$(backup_user_rules_file)"
  mv "$tmp_file" "$USER_RULES_FILE"

  echo
  echo -e "${COLOR_GREEN}user.txt 已覆盖更新。${COLOR_RESET}"
  echo "备份文件: $backup_file"
  restart_after_user_rules_change
  pause
}

execute_with_pause() {
  local title="$1"
  shift
  local rc

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}${title}${COLOR_RESET}"
  echo

  set +e
  "$@"
  rc=$?
  set -e

  echo
  if [[ "$rc" -eq 0 ]]; then
    echo -e "${COLOR_GREEN}命令执行完成。${COLOR_RESET}"
  else
    echo -e "${COLOR_RED}命令失败，退出码: ${rc}${COLOR_RESET}"
  fi
  pause
}

run_adguard_cmd() {
  local title="$1"
  shift
  execute_with_pause "$title" "$ADGUARD_BIN" "$@"
}

prompt_words() {
  local prompt="$1"

  read -r -a PROMPT_WORDS -p "$prompt" || return 1
  [[ "${#PROMPT_WORDS[@]}" -gt 0 ]]
}

list_firefox_profiles() {
  local -a firefox_roots=()
  local root

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}Firefox 配置目录${COLOR_RESET}"
  echo

  if [[ -d "$HOME/.mozilla/firefox" ]]; then
    firefox_roots+=("$HOME/.mozilla/firefox")
  fi
  if [[ -d "$HOME/.config/mozilla/firefox" ]]; then
    firefox_roots+=("$HOME/.config/mozilla/firefox")
  fi

  if [[ "${#firefox_roots[@]}" -eq 0 ]]; then
    echo "未找到 Firefox profile 目录。"
    pause
    return 0
  fi

  for root in "${firefox_roots[@]}"; do
    echo "$root"
    find "$root" -maxdepth 1 -mindepth 1 -type d | sort
    echo
  done
  pause
}

show_local_cert_files() {
  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}本地 AdGuard 证书文件${COLOR_RESET}"
  echo

  if [[ ! -d "$HOME/.local/share/adguard-cli" ]]; then
    echo "未找到 ~/.local/share/adguard-cli"
    pause
    return 0
  fi

  find "$HOME/.local/share/adguard-cli" -maxdepth 4 -type f \
    \( -iname '*.cer' -o -iname '*.crt' -o -iname '*.pem' -o -iname '*.key' \) | sort
  pause
}

install_system_trust_certificate() {
  local -a candidates=()
  local file choice="" cert_path="" target rc_install rc_trust

  clear_screen
  print_banner
  echo -e "${COLOR_YELLOW}导入证书到 Arch 系统信任库${COLOR_RESET}"
  echo

  if ! cmd_exists sudo; then
    echo "缺少 sudo，无法写入系统信任库。"
    pause
    return 0
  fi

  if ! cmd_exists trust; then
    echo "缺少 trust 命令，请先安装 p11-kit。"
    pause
    return 0
  fi

  if [[ -d "$HOME/.local/share/adguard-cli" ]]; then
    while IFS= read -r file; do
      candidates+=("$file")
    done < <(
      find "$HOME/.local/share/adguard-cli" -maxdepth 4 -type f \
        \( -iname '*.cer' -o -iname '*.crt' \) | sort
    )
  fi

  if [[ "${#candidates[@]}" -gt 0 ]]; then
    echo "检测到以下证书候选："
    for i in "${!candidates[@]}"; do
      printf "%2d) %s\n" "$((i + 1))" "${candidates[$i]}"
    done
    echo
    read -r -p "请输入序号，或直接输入自定义路径 [1]: " choice

    if [[ -z "$choice" ]]; then
      cert_path="${candidates[0]}"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#candidates[@]} )); then
      cert_path="${candidates[$((choice - 1))]}"
    else
      cert_path="$choice"
    fi
  else
    if ! cert_path="$(prompt_nonempty "请输入 .cer/.crt 证书路径: ")"; then
      pause
      return 0
    fi
  fi

  if [[ ! -f "$cert_path" ]]; then
    echo "证书不存在: $cert_path"
    pause
    return 0
  fi

  target="/etc/ca-certificates/trust-source/anchors/adguard-cli-ca.crt"
  echo "将执行以下命令："
  echo "sudo install -Dm644 \"$cert_path\" \"$target\""
  echo "sudo trust extract-compat"
  echo

  if ! confirm_action "继续导入? [y/N]: "; then
    echo "已取消。"
    pause
    return 0
  fi

  set +e
  sudo install -Dm644 "$cert_path" "$target"
  rc_install=$?
  if [[ "$rc_install" -eq 0 ]]; then
    sudo trust extract-compat
    rc_trust=$?
  else
    rc_trust=1
  fi
  set -e

  echo
  if [[ "$rc_install" -eq 0 && "$rc_trust" -eq 0 ]]; then
    echo -e "${COLOR_GREEN}系统证书已更新。${COLOR_RESET}"
    echo "如果你用 Firefox，建议确认 about:config 中"
    echo "security.enterprise_roots.enabled = true，然后重启 Firefox。"
  else
    echo -e "${COLOR_RED}导入失败。${COLOR_RESET}"
  fi
  pause
}

install_custom_filter() {
  local scope_label="$1"
  shift
  local -a scope=("$@")
  local url title
  local -a cmd=()

  if ! url="$(prompt_nonempty "请输入过滤器 URL 或本地文件路径: ")"; then
    pause
    return 0
  fi

  read -r -p "可选标题 [留空跳过]: " title
  cmd=("$ADGUARD_BIN" "${scope[@]}" install "$url")

  if [[ -n "$title" ]]; then
    cmd+=(--title "$title")
  fi

  if [[ "${scope[0]}" == "filters" ]] && confirm_action "是否标记为 trusted? [y/N]: "; then
    cmd+=(--trusted)
  fi

  execute_with_pause "${scope_label}安装自定义过滤器" "${cmd[@]}"
}

add_filters_by_ids() {
  local title="$1"
  shift
  local -a scope=("$@")

  echo "建议输入过滤器 ID，多个值用空格分隔。"
  if ! prompt_words "> "; then
    echo "至少输入一个过滤器 ID。"
    pause
    return 0
  fi

  run_adguard_cmd "$title" "${scope[@]}" add "${PROMPT_WORDS[@]}"
}

toggle_filters() {
  local title="$1"
  local action="$2"
  shift 2
  local -a scope=("$@")

  echo "请输入过滤器 ID，多个值用空格分隔。"
  if ! prompt_words "> "; then
    echo "至少输入一个过滤器 ID。"
    pause
    return 0
  fi

  run_adguard_cmd "$title" "${scope[@]}" "$action" "${PROMPT_WORDS[@]}"
}

remove_single_filter() {
  local title="$1"
  shift
  local -a scope=("$@")
  local filter_id

  if ! filter_id="$(prompt_nonempty "请输入过滤器 ID: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "$title" "${scope[@]}" remove "$filter_id"
}

set_filter_title() {
  local title="$1"
  shift
  local -a scope=("$@")
  local filter_id filter_title

  if ! filter_id="$(prompt_nonempty "请输入过滤器 ID: ")"; then
    pause
    return 0
  fi
  if ! filter_title="$(prompt_nonempty "请输入新标题: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "$title" "${scope[@]}" set-title "$filter_id" "$filter_title"
}

set_filter_trusted() {
  local filter_id trusted

  if ! filter_id="$(prompt_nonempty "请输入自定义过滤器 ID: ")"; then
    pause
    return 0
  fi

  read -r -p "是否 trusted? [true/false]: " trusted
  case "$trusted" in
    true|false)
      ;;
    *)
      echo "请输入 true 或 false。"
      pause
      return 0
      ;;
  esac

  run_adguard_cmd "设置自定义过滤器 trusted" filters set-trusted "$filter_id" "$trusted"
}

config_show_section() {
  local section

  if ! section="$(prompt_nonempty "请输入 section 名称: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "查看配置 section" config show "$section"
}

config_get_key() {
  local key

  if ! key="$(prompt_nonempty "请输入配置键名: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "读取配置键" config get "$key"
}

config_set_key() {
  local key value

  if ! key="$(prompt_nonempty "请输入配置键名: ")"; then
    pause
    return 0
  fi
  if ! value="$(prompt_nonempty "请输入要写入的值: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "写入配置键" config set "$key" "$value"
}

config_list_add() {
  local key

  if ! key="$(prompt_nonempty "请输入列表键名: ")"; then
    pause
    return 0
  fi

  echo "请输入要追加的值，多个值用空格分隔。"
  if ! prompt_words "> "; then
    echo "至少输入一个值。"
    pause
    return 0
  fi

  run_adguard_cmd "向列表追加值" config list-add "$key" "${PROMPT_WORDS[@]}"
}

config_list_remove() {
  local key value

  if ! key="$(prompt_nonempty "请输入列表键名: ")"; then
    pause
    return 0
  fi
  if ! value="$(prompt_nonempty "请输入要删除的值: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "从列表删除值" config list-remove "$key" "$value"
}

config_reset_key() {
  local key

  if ! key="$(prompt_nonempty "请输入要重置的配置键名: ")"; then
    pause
    return 0
  fi

  run_adguard_cmd "重置单个配置键" config reset "$key"
}

config_reset_all() {
  if ! confirm_action "确认重置全部配置到默认值? [y/N]: "; then
    echo "已取消。"
    pause
    return 0
  fi

  run_adguard_cmd "重置全部配置" config reset --all
}

export_logs_menu() {
  local output_path default_path

  default_path="$(default_export_path)"
  read -r -p "输出目录或 zip 路径 [默认: ${default_path}]: " output_path
  output_path="${output_path:-$default_path}"
  run_adguard_cmd "导出日志" export-logs -o "$output_path"
}

export_settings_menu() {
  local output_path default_path

  default_path="$(default_export_path)"
  read -r -p "输出目录或 zip 路径 [默认: ${default_path}]: " output_path
  output_path="${output_path:-$default_path}"
  run_adguard_cmd "导出设置" export-settings -o "$output_path"
}

import_settings_menu() {
  local input_path

  if ! input_path="$(prompt_nonempty "请输入要导入的 zip 路径: ")"; then
    pause
    return 0
  fi

  if [[ ! -f "$input_path" ]]; then
    echo "文件不存在: $input_path"
    pause
    return 0
  fi

  if ! confirm_action "确认导入设置并覆盖当前配置? [y/N]: "; then
    echo "已取消。"
    pause
    return 0
  fi

  run_adguard_cmd "导入设置" import-settings -i "$input_path"
}

run_speed_custom_chunks() {
  echo "请输入 chunk 大小，多个值用空格分隔，例如：16 256 1350 8192"
  if ! prompt_words "> "; then
    echo "至少输入一个 chunk。"
    pause
    return 0
  fi

  run_adguard_cmd "自定义 speed 测试" speed -c "${PROMPT_WORDS[@]}"
}

show_main_menu() {
  cat <<'EOF'
1) 状态与服务控制
2) 配置管理
3) 自定义规则（user.txt）
4) HTTP(S) 过滤器
5) DNS 过滤器
6) Userscripts
7) 证书与信任
8) 更新与许可证
9) 导入 / 导出
10) 日志查看与屏蔽记录
11) 性能测试
12) 查看 adguard-cli 全帮助
0) 退出
EOF
}

show_user_rules_menu() {
  cat <<'EOF'
1) 查看当前 user.txt
2) 新增元素隐藏规则
3) 新增元素例外规则
4) 新增网络拦截规则
5) 新增注释
6) 从文件追加导入规则
7) 用文件覆盖导入规则
8) 查看规则示例
9) 删除指定行
0) 返回主菜单
EOF
}

show_service_menu() {
  cat <<'EOF'
1) 查看状态
2) 启动服务
3) 停止服务
4) 重启服务
5) 运行配置向导
0) 返回主菜单
EOF
}

show_config_menu() {
  cat <<'EOF'
1) 查看全部配置
2) 查看指定 section
3) 读取配置键
4) 写入配置键
5) 列表追加值
6) 列表删除值
7) 重置单个配置键
8) 重置全部配置
0) 返回主菜单
EOF
}

show_filters_menu() {
  cat <<'EOF'
1) 列出已安装过滤器
2) 列出全部可用过滤器
3) 添加内置过滤器
4) 安装自定义过滤器
5) 删除过滤器
6) 启用过滤器
7) 禁用过滤器
8) 更新过滤器
9) 设置 trusted
10) 设置标题
0) 返回主菜单
EOF
}

show_dns_filters_menu() {
  cat <<'EOF'
1) 列出已安装 DNS 过滤器
2) 列出全部可用 DNS 过滤器
3) 添加内置 DNS 过滤器
4) 安装自定义 DNS 过滤器
5) 删除 DNS 过滤器
6) 启用 DNS 过滤器
7) 禁用 DNS 过滤器
8) 刷新 DNS 过滤器列表
9) 设置 DNS 过滤器标题
0) 返回主菜单
EOF
}

show_userscripts_menu() {
  cat <<'EOF'
1) 列出 userscripts
2) 安装 userscript
3) 删除 userscript
4) 启用 userscript
5) 禁用 userscript
0) 返回主菜单
EOF
}

show_cert_menu() {
  cat <<'EOF'
1) 生成 HTTPS 过滤证书
2) 生成证书并导入指定 Firefox profile
3) 列出 Firefox profiles
4) 查看本地证书文件
5) 导入证书到系统信任库
0) 返回主菜单
EOF
}

show_update_menu() {
  cat <<'EOF'
1) 查看许可证信息
2) 重置许可证
3) 检查更新
4) 更新 AdGuard CLI
0) 返回主菜单
EOF
}

show_import_export_menu() {
  cat <<'EOF'
1) 导出日志
2) 导出设置
3) 导入设置
0) 返回主菜单
EOF
}

show_logs_menu() {
  cat <<'EOF'
1) 查看日志目录概览
2) 查看 app.log 最新若干行
3) 查看 proxy.log 最新若干行
4) 查看 access.log 最新若干行
5) 查看最近屏蔽日志（BLOCKED）
6) 搜索 access.log 关键字
7) 搜索屏蔽日志关键字
8) 实时跟踪 access.log
9) 实时跟踪屏蔽日志
0) 返回主菜单
EOF
}

show_speed_menu() {
  cat <<'EOF'
1) 默认 speed 测试
2) JSON speed 测试
3) 自定义 chunk speed 测试
0) 返回主菜单
EOF
}

service_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_service_menu
    echo
    read -r -p "请选择 [0-5]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "查看 AdGuard 状态" status ;;
      2) run_adguard_cmd "启动 AdGuard" start ;;
      3) run_adguard_cmd "停止 AdGuard" stop ;;
      4) run_adguard_cmd "重启 AdGuard" restart ;;
      5) run_adguard_cmd "运行 AdGuard 配置向导" configure ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

user_rules_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_user_rules_menu
    echo
    read -r -p "请选择 [0-9]: " choice || break

    case "$choice" in
      1) show_user_rules_file ;;
      2) add_cosmetic_hide_rule ;;
      3) add_cosmetic_exception_rule ;;
      4) add_network_block_rule ;;
      5) add_user_rule_comment ;;
      6) import_user_rules_append ;;
      7) import_user_rules_replace ;;
      8) show_user_rule_examples ;;
      9) delete_user_rule_line ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

config_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_config_menu
    echo
    read -r -p "请选择 [0-8]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "查看全部配置" config show ;;
      2) config_show_section ;;
      3) config_get_key ;;
      4) config_set_key ;;
      5) config_list_add ;;
      6) config_list_remove ;;
      7) config_reset_key ;;
      8) config_reset_all ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

filters_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_filters_menu
    echo
    read -r -p "请选择 [0-10]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "列出已安装过滤器" filters list ;;
      2) run_adguard_cmd "列出全部可用过滤器" filters list --all ;;
      3) add_filters_by_ids "添加内置过滤器" filters ;;
      4) install_custom_filter "HTTP(S) 过滤器" filters ;;
      5) remove_single_filter "删除过滤器" filters ;;
      6) toggle_filters "启用过滤器" enable filters ;;
      7) toggle_filters "禁用过滤器" disable filters ;;
      8) run_adguard_cmd "更新过滤器" filters update ;;
      9) set_filter_trusted ;;
      10) set_filter_title "设置过滤器标题" filters ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

dns_filters_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_dns_filters_menu
    echo
    read -r -p "请选择 [0-9]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "列出已安装 DNS 过滤器" dns filters list ;;
      2) run_adguard_cmd "列出全部可用 DNS 过滤器" dns filters list --all ;;
      3) add_filters_by_ids "添加内置 DNS 过滤器" dns filters ;;
      4) install_custom_filter "DNS 过滤器" dns filters ;;
      5) remove_single_filter "删除 DNS 过滤器" dns filters ;;
      6) toggle_filters "启用 DNS 过滤器" enable dns filters ;;
      7) toggle_filters "禁用 DNS 过滤器" disable dns filters ;;
      8) run_adguard_cmd "刷新 DNS 过滤器列表" check-update ;;
      9) set_filter_title "设置 DNS 过滤器标题" dns filters ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

userscripts_menu() {
  local choice name url

  while true; do
    clear_screen
    print_banner
    show_userscripts_menu
    echo
    read -r -p "请选择 [0-5]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "列出 userscripts" userscripts list ;;
      2)
        if ! url="$(prompt_nonempty "请输入 userscript URL: ")"; then
          pause
          continue
        fi
        run_adguard_cmd "安装 userscript" userscripts install "$url"
        ;;
      3)
        if ! name="$(prompt_nonempty "请输入 userscript 名称: ")"; then
          pause
          continue
        fi
        run_adguard_cmd "删除 userscript" userscripts remove "$name"
        ;;
      4)
        if ! name="$(prompt_nonempty "请输入 userscript 名称: ")"; then
          pause
          continue
        fi
        run_adguard_cmd "启用 userscript" userscripts enable "$name"
        ;;
      5)
        if ! name="$(prompt_nonempty "请输入 userscript 名称: ")"; then
          pause
          continue
        fi
        run_adguard_cmd "禁用 userscript" userscripts disable "$name"
        ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

cert_menu() {
  local choice profile

  while true; do
    clear_screen
    print_banner
    show_cert_menu
    echo
    read -r -p "请选择 [0-5]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "生成 HTTPS 过滤证书" cert ;;
      2)
        if ! profile="$(prompt_nonempty "请输入 Firefox profile 目录名: ")"; then
          pause
          continue
        fi
        run_adguard_cmd "生成证书并导入 Firefox profile" cert --firefox-profile "$profile"
        ;;
      3) list_firefox_profiles ;;
      4) show_local_cert_files ;;
      5) install_system_trust_certificate ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

update_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_update_menu
    echo
    read -r -p "请选择 [0-4]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "查看许可证信息" license ;;
      2)
        if confirm_action "确认重置许可证? [y/N]: "; then
          run_adguard_cmd "重置许可证" reset-license
        else
          echo "已取消。"
          pause
        fi
        ;;
      3) run_adguard_cmd "检查更新" check-update ;;
      4) run_adguard_cmd "更新 AdGuard CLI" update ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

import_export_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_import_export_menu
    echo
    read -r -p "请选择 [0-3]: " choice || break

    case "$choice" in
      1) export_logs_menu ;;
      2) export_settings_menu ;;
      3) import_settings_menu ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

logs_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_logs_menu
    echo
    read -r -p "请选择 [0-9]: " choice || break

    case "$choice" in
      1) show_logs_overview ;;
      2) show_log_tail "查看 app.log" "$APP_LOG_FILE" ;;
      3) show_log_tail "查看 proxy.log" "$PROXY_LOG_FILE" ;;
      4) show_log_tail "查看 access.log" "$ACCESS_LOG_FILE" ;;
      5) show_recent_blocked_requests ;;
      6) search_log_by_keyword "搜索 access.log" "$ACCESS_LOG_FILE" ;;
      7) search_log_by_keyword "搜索屏蔽日志" "$ACCESS_LOG_FILE" true ;;
      8) follow_log_file "实时跟踪 access.log" "$ACCESS_LOG_FILE" ;;
      9) follow_blocked_requests ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

speed_menu() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_speed_menu
    echo
    read -r -p "请选择 [0-3]: " choice || break

    case "$choice" in
      1) run_adguard_cmd "默认 speed 测试" speed ;;
      2) run_adguard_cmd "JSON speed 测试" speed --json ;;
      3) run_speed_custom_chunks ;;
      0) return 0 ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

panel() {
  local choice

  while true; do
    clear_screen
    print_banner
    show_main_menu
    echo
    read -r -p "请选择 [0-12]: " choice || break

    case "$choice" in
      1) service_menu ;;
      2) config_menu ;;
      3) user_rules_menu ;;
      4) filters_menu ;;
      5) dns_filters_menu ;;
      6) userscripts_menu ;;
      7) cert_menu ;;
      8) update_menu ;;
      9) import_export_menu ;;
      10) logs_menu ;;
      11) speed_menu ;;
      12) run_adguard_cmd "adguard-cli --help-all" --help-all ;;
      0)
        clear_screen
        print_banner
        echo -e "${COLOR_GREEN}已退出。${COLOR_RESET}"
        return 0
        ;;
      *)
        echo "无效输入。"
        pause
        ;;
    esac
  done
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --bin)
        if [[ $# -lt 2 ]]; then
          echo "--bin 需要提供 adguard-cli 路径。"
          return 1
        fi
        ADGUARD_BIN="$2"
        shift 2
        ;;
      -h|--help|help)
        usage
        return 0
        ;;
      *)
        echo "未知参数: $1"
        usage
        return 1
        ;;
    esac
  done

  require_adguard_bin
  panel
}

main "$@"
