#!/usr/bin/env bash

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  SETUP_GREEN='\033[38;5;42m' SETUP_YELLOW='\033[38;5;214m' SETUP_RED='\033[38;5;196m'
  SETUP_CYAN='\033[38;5;86m' SETUP_PURPLE='\033[38;5;99m'
  SETUP_DIM='\033[38;5;245m' SETUP_BOLD='\033[1m' SETUP_RESET='\033[0m'
else
  SETUP_GREEN='' SETUP_YELLOW='' SETUP_RED='' SETUP_CYAN='' SETUP_PURPLE=''
  SETUP_DIM='' SETUP_BOLD='' SETUP_RESET=''
fi

log() { printf '%b[setup]%b %s\n' "$SETUP_GREEN" "$SETUP_RESET" "$*"; }
warn() { printf '%b[setup] WARN:%b %s\n' "$SETUP_YELLOW" "$SETUP_RESET" "$*" >&2; }
die() {
  local was_compact="${PROGRESS_COMPACT:-0}"
  [ "$was_compact" != 1 ] || progress_restore_terminal
  printf '%b[setup] ERROR:%b %s\n' "$SETUP_RED" "$SETUP_RESET" "$*" >&2
  if [ "$was_compact" = 1 ] && [ -n "${SETUP_LOG_FILE:-}" ]; then
    printf 'Detailed log: %s\n' "$SETUP_LOG_FILE" >&2
  fi
  exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }

sudo_release() {
  [ -n "${SUDO_KEEPALIVE_PID:-}" ] || return 0
  kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  SUDO_KEEPALIVE_PID=""
}

sudo_acquire() {
  SUDO_KEEPALIVE_PID=""
  [ "${DRY_RUN:-0}" != 1 ] || return 0
  [ "$(id -u)" -ne 0 ] || return 0
  has sudo || die "Administrator access is required, but sudo is not installed."

  printf '\n%bAdministrator approval%b\n' "$SETUP_BOLD" "$SETUP_RESET"
  printf 'Vedup asks once before installation and keeps this temporary approval active.\n'
  printf 'Your password is handled by sudo and is never read or stored by Vedup.\n\n'
  sudo -v || die "Administrator approval was not granted."
  printf '%b✓%b Administrator approval ready.\n' "$SETUP_GREEN" "$SETUP_RESET"

  (
    trap - ERR
    set +e
    while :; do
      sleep 50
      sudo -n -v >/dev/null 2>&1 || exit 0
    done
  ) &
  SUDO_KEEPALIVE_PID=$!
  trap sudo_release EXIT
}

progress_init() {
  local terminal_columns
  PROGRESS_CURRENT=0
  PROGRESS_COMPACT=0
  PROGRESS_DASHBOARD_DRAWN=0
  PROGRESS_DASHBOARD_ROWS=9
  PROGRESS_ACTIVITY_PID=""
  PROGRESS_FD=1
  PROGRESS_COLUMNS=80
  terminal_columns="$(tput cols 2>/dev/null || true)"
  case "$terminal_columns" in ''|*[!0-9]*) ;; *) PROGRESS_COLUMNS="$terminal_columns" ;; esac
  PROGRESS_STAGE_NAME="Starting setup"
  PROGRESS_STAGE_STARTED="$(date +%s)"
  SETUP_LOG_FILE="${MACAUTOSETUP_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/macautosetup/logs/$(date -u +%Y%m%dT%H%M%SZ)-$$.log}"
  export SETUP_LOG_FILE
  if [ "${DRY_RUN:-0}" != 1 ]; then
    mkdir -p "$(dirname "$SETUP_LOG_FILE")"
    exec 3>&1
    if { [ -t 1 ] || [ "${MACAUTOSETUP_TEST_COMPACT:-0}" = 1 ]; } && \
      [ "${VERBOSE:-0}" != 1 ] && [ "${TERM:-}" != dumb ]; then
      PROGRESS_COMPACT=1
      PROGRESS_FD=3
      exec >>"$SETUP_LOG_FILE" 2>&1
    else
      exec > >(tee -a "$SETUP_LOG_FILE") 2>&1
    fi
  fi
}

progress_header() {
  printf '%bVedup%b\n' "$SETUP_BOLD" "$SETUP_RESET" >&"$PROGRESS_FD"
  printf 'Machine: %s\nProfile: %s\n' "$1" "$2" >&"$PROGRESS_FD"
  if [ "$PROGRESS_COMPACT" = 1 ]; then
    printf '%bConcise view:%b full output is being saved to %s\n' \
      "$SETUP_DIM" "$SETUP_RESET" "$SETUP_LOG_FILE" >&3
  fi
}

progress_stop_activity() {
  [ -n "${PROGRESS_ACTIVITY_PID:-}" ] || return 0
  kill "$PROGRESS_ACTIVITY_PID" 2>/dev/null || true
  wait "$PROGRESS_ACTIVITY_PID" 2>/dev/null || true
  PROGRESS_ACTIVITY_PID=""
}

progress_start_activity() {
  [ "$PROGRESS_COMPACT" = 1 ] || return 0
  (
    local elapsed frame=0 line limit index
    local frames=('◐' '◓' '◑' '◒')
    trap - ERR
    set +e
    while :; do
      elapsed=$(($(date +%s) - PROGRESS_STAGE_STARTED))
      printf '\0337\033[6A' >&3
      printf '\r\033[2K  %b%s Working · %ss%b\n' "$SETUP_CYAN" "${frames[$frame]}" "$elapsed" "$SETUP_RESET" >&3
      index=0
      limit=$((PROGRESS_COLUMNS - 6))
      [ "$limit" -ge 12 ] || limit=12
      while IFS= read -r line && [ "$index" -lt 5 ]; do
        if [ "${#line}" -gt "$limit" ]; then line="${line:0:$((limit - 3))}..."; fi
        printf '\r\033[2K  %b│%b %s\n' "$SETUP_DIM" "$SETUP_RESET" "$line" >&3
        index=$((index + 1))
      done < <(tail -n 5 "$SETUP_LOG_FILE" 2>/dev/null | awk '{ gsub(sprintf("%c", 27) "\\[[0-9;?]*[ -/]*[@-~]", ""); gsub(/\r/, ""); print }')
      while [ "$index" -lt 5 ]; do
        printf '\r\033[2K  %b│%b\n' "$SETUP_DIM" "$SETUP_RESET" >&3
        index=$((index + 1))
      done
      printf '\0338' >&3
      frame=$(((frame + 1) % ${#frames[@]}))
      sleep "${MACAUTOSETUP_ACTIVITY_INTERVAL:-0.5}"
    done
  ) &
  PROGRESS_ACTIVITY_PID=$!
}

progress_begin() {
  local stage_name="$1" description="${2:-}" limit
  progress_stop_activity
  PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
  PROGRESS_STAGE_NAME="$stage_name"
  PROGRESS_STAGE_STARTED="$(date +%s)"
  if [ "$PROGRESS_COMPACT" = 1 ]; then
    limit=$((PROGRESS_COLUMNS - 13))
    [ "$limit" -ge 16 ] || limit=16
    if [ "${#stage_name}" -gt "$limit" ]; then stage_name="${stage_name:0:$((limit - 3))}..."; fi
    limit=$((PROGRESS_COLUMNS - 4))
    [ "$limit" -ge 16 ] || limit=16
    if [ "${#description}" -gt "$limit" ]; then description="${description:0:$((limit - 3))}..."; fi
  fi
  PROGRESS_DISPLAY_STAGE="$stage_name"
  if [ "$PROGRESS_COMPACT" = 1 ] && [ "$PROGRESS_DASHBOARD_DRAWN" = 1 ]; then
    printf '\033[%sA' "$PROGRESS_DASHBOARD_ROWS" >&3
  elif [ "$PROGRESS_COMPACT" != 1 ]; then
    printf '\n' >&"$PROGRESS_FD"
  fi
  [ "$PROGRESS_COMPACT" != 1 ] || printf '\r\033[2K' >&3
  progress_bar
  [ "$PROGRESS_COMPACT" != 1 ] || printf '\r\033[2K' >&3
  printf '%b◆%b [%s/%s] %b%s%b\n' "$SETUP_CYAN" "$SETUP_RESET" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" \
    "$SETUP_BOLD" "$stage_name" "$SETUP_RESET" >&"$PROGRESS_FD"
  [ "$PROGRESS_COMPACT" != 1 ] || printf '\r\033[2K' >&3
  if [ -n "$description" ]; then printf '  %b%s%b\n' "$SETUP_DIM" "$description" "$SETUP_RESET" >&"$PROGRESS_FD"
  else printf '\n' >&"$PROGRESS_FD"; fi
  if [ "$PROGRESS_COMPACT" = 1 ]; then
    printf '  %b◐ Working · 0s%b\n' "$SETUP_CYAN" "$SETUP_RESET" >&3
    printf '  %b│%b\n  %b│%b\n  %b│%b\n  %b│%b\n  %b│%b\n' \
      "$SETUP_DIM" "$SETUP_RESET" "$SETUP_DIM" "$SETUP_RESET" \
      "$SETUP_DIM" "$SETUP_RESET" "$SETUP_DIM" "$SETUP_RESET" \
      "$SETUP_DIM" "$SETUP_RESET" >&3
  fi
  PROGRESS_DASHBOARD_DRAWN=1
  progress_start_activity
}

progress_bar() {
  local width=24 filled empty index bar=""
  if [ "$PROGRESS_COMPACT" = 1 ] && [ "$PROGRESS_COLUMNS" -lt 34 ]; then
    width=$((PROGRESS_COLUMNS - 8))
    [ "$width" -ge 10 ] || width=10
  fi
  filled=$((PROGRESS_CURRENT * width / PROGRESS_TOTAL))
  empty=$((width - filled))
  index=0
  while [ "$index" -lt "$filled" ]; do bar="${bar}█"; index=$((index + 1)); done
  index=0
  while [ "$index" -lt "$empty" ]; do bar="${bar}░"; index=$((index + 1)); done
  printf '%b%s%b  %s%%\n' "$SETUP_PURPLE" "$bar" "$SETUP_RESET" "$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))" \
    >&"$PROGRESS_FD"
}

progress_done() {
  local elapsed
  progress_stop_activity
  elapsed=$(($(date +%s) - PROGRESS_STAGE_STARTED))
  if [ "$PROGRESS_COMPACT" = 1 ]; then
    printf '\033[%sA' "$PROGRESS_DASHBOARD_ROWS" >&3
    printf '\r\033[2K' >&3
    progress_bar
    printf '\r\033[2K%b◆%b [%s/%s] %b%s%b\n' "$SETUP_CYAN" "$SETUP_RESET" \
      "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" "$SETUP_BOLD" "$PROGRESS_DISPLAY_STAGE" "$SETUP_RESET" >&3
    printf '\r\033[2K' >&3
  fi
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '  %b✓%b Previewed %b(%ss)%b\n' "$SETUP_GREEN" "$SETUP_RESET" "$SETUP_DIM" "$elapsed" "$SETUP_RESET" \
      >&"$PROGRESS_FD"
  else
    printf '  %b✓%b Complete %b(%ss)%b\n' "$SETUP_GREEN" "$SETUP_RESET" "$SETUP_DIM" "$elapsed" "$SETUP_RESET" \
      >&"$PROGRESS_FD"
  fi
  if [ "$PROGRESS_COMPACT" = 1 ]; then
    printf '\r\033[2K\n\r\033[2K\n\r\033[2K\n\r\033[2K\n\r\033[2K\n\r\033[2K\n' >&3
  fi
}

progress_restore_terminal() {
  [ "${PROGRESS_COMPACT:-0}" = 1 ] || return 0
  progress_stop_activity
  if [ "${PROGRESS_DASHBOARD_DRAWN:-0}" = 1 ]; then
    printf '\033[%sA' "$PROGRESS_DASHBOARD_ROWS" >&3
    local row=0
    while [ "$row" -lt "$PROGRESS_DASHBOARD_ROWS" ]; do
      printf '\r\033[2K\n' >&3
      row=$((row + 1))
    done
  fi
  exec 1>&3 2>&3
  PROGRESS_COMPACT=0
  PROGRESS_FD=1
  PROGRESS_DASHBOARD_DRAWN=0
}

progress_failed() {
  local code="$1" line="$2"
  local was_compact="${PROGRESS_COMPACT:-0}"
  trap - ERR
  [ "$was_compact" != 1 ] || progress_restore_terminal
  printf '\n%b✗ %s failed%b near line %s (exit %s).\n' "$SETUP_RED" "$PROGRESS_STAGE_NAME" "$SETUP_RESET" "$line" "$code" >&2
  if [ -n "${SETUP_LOG_FILE:-}" ] && [ "${DRY_RUN:-0}" != 1 ]; then
    if [ "$was_compact" = 1 ]; then
      printf '\nRecent log output:\n' >&2
      tail -n 18 "$SETUP_LOG_FILE" | sed 's/^/  │ /' >&2
      printf '\n' >&2
    fi
    printf '  Detailed log: %s\n' "$SETUP_LOG_FILE" >&2
    printf '  Setup is idempotent; correct the problem and rerun the same command.\n' >&2
  fi
  exit "$code"
}

progress_finish() {
  local state_dir latest_dotfiles latest_macos
  local warning_count
  progress_restore_terminal
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '\n%b╭─ Dry-run complete ─────────────────────────────────────────╮%b\n' "$SETUP_PURPLE" "$SETUP_RESET"
    printf '  %s stage(s) previewed; no machine changes were made.\n' "$PROGRESS_CURRENT"
  else
    printf '\n%b╭─ Setup complete ───────────────────────────────────────────╮%b\n' "$SETUP_GREEN" "$SETUP_RESET"
    printf '  %b✓%b %s stage(s) finished successfully.\n' "$SETUP_GREEN" "$SETUP_RESET" "$PROGRESS_CURRENT"
  fi
  if [ "${DRY_RUN:-0}" != 1 ]; then
    printf 'Detailed log: %s\n' "$SETUP_LOG_FILE"
    warning_count="$(grep -c '\[setup\] WARN:' "$SETUP_LOG_FILE" 2>/dev/null || true)"
    if [ "${warning_count:-0}" -gt 0 ]; then
      printf '%bWarnings:%b %s (see the detailed log)\n' "$SETUP_YELLOW" "$SETUP_RESET" "$warning_count"
    fi
    state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/macautosetup"
    latest_dotfiles="$(awk 'NF { value=$0 } END { print value }' "$state_dir/backups.list" 2>/dev/null || true)"
    latest_macos="$(awk 'NF { value=$0 } END { print value }' "$state_dir/macos-preferences.list" 2>/dev/null || true)"
    if [ -n "$latest_dotfiles" ] || [ -n "$latest_macos" ]; then
      printf 'Recovery snapshots:\n'
      [ -z "$latest_dotfiles" ] || printf '  Dotfiles:          %s\n' "$latest_dotfiles"
      [ -z "$latest_macos" ] || printf '  macOS preferences: %s\n' "$latest_macos"
    fi
  fi
  printf '%bNext:%b open a new terminal to use the configured shell and PATH.\n' "$SETUP_CYAN" "$SETUP_RESET"
  printf '%b╰────────────────────────────────────────────────────────────╯%b\n' "$([ "${DRY_RUN:-0}" = 1 ] && printf '%s' "$SETUP_PURPLE" || printf '%s' "$SETUP_GREEN")" "$SETUP_RESET"
}

quote_command() {
  printf ' %q' "$@"
  printf '\n'
}

run() {
  if [ "${DRY_RUN:-0}" = "1" ]; then
    printf '[dry-run]'
    quote_command "$@"
    return 0
  fi
  "$@"
}

sudo_run() {
  if [ "$(id -u)" -eq 0 ]; then
    run "$@"
  elif has sudo; then
    run sudo -n "$@"
  else
    die "Administrator access is required for: $*"
  fi
}

sha256_file() {
  if has sha256sum; then
    sha256sum "$1" | awk '{print $1}'
  elif has shasum; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    die "A SHA-256 tool (sha256sum or shasum) is required."
  fi
}

download_verified() {
  local url="$1" expected="$2" output="$3" force="${4:-0}" actual
  if [ "$force" = force ]; then mkdir -p "$(dirname "$output")"
  else run mkdir -p "$(dirname "$output")"; fi
  if [ "${DRY_RUN:-0}" = "1" ] && [ "$force" != force ]; then
    printf '[dry-run] download %s -> %s (sha256 %s)\n' "$url" "$output" "$expected"
    return 0
  fi
  curl -fsSL --retry 3 --proto '=https' --tlsv1.2 "$url" -o "$output"
  actual="$(sha256_file "$output")"
  [ "$actual" = "$expected" ] || die "Checksum mismatch for $url"
}

repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}
