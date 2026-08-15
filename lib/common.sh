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
die() { printf '%b[setup] ERROR:%b %s\n' "$SETUP_RED" "$SETUP_RESET" "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

progress_init() {
  PROGRESS_CURRENT=0
  PROGRESS_STAGE_NAME="Starting setup"
  PROGRESS_STAGE_STARTED="$(date +%s)"
  SETUP_LOG_FILE="${MACAUTOSETUP_LOG_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/macautosetup/logs/$(date -u +%Y%m%dT%H%M%SZ)-$$.log}"
  export SETUP_LOG_FILE
  if [ "${DRY_RUN:-0}" != 1 ]; then
    mkdir -p "$(dirname "$SETUP_LOG_FILE")"
    exec > >(tee -a "$SETUP_LOG_FILE") 2>&1
  fi
}

progress_begin() {
  PROGRESS_CURRENT=$((PROGRESS_CURRENT + 1))
  PROGRESS_STAGE_NAME="$1"
  PROGRESS_STAGE_STARTED="$(date +%s)"
  printf '\n'
  progress_bar
  printf '%b◆%b [%s/%s] %b%s%b\n' "$SETUP_CYAN" "$SETUP_RESET" "$PROGRESS_CURRENT" "$PROGRESS_TOTAL" \
    "$SETUP_BOLD" "$PROGRESS_STAGE_NAME" "$SETUP_RESET"
  [ -z "${2:-}" ] || printf '  %b%s%b\n' "$SETUP_DIM" "$2" "$SETUP_RESET"
}

progress_bar() {
  local width=24 filled empty index bar=""
  filled=$((PROGRESS_CURRENT * width / PROGRESS_TOTAL))
  empty=$((width - filled))
  index=0
  while [ "$index" -lt "$filled" ]; do bar="${bar}█"; index=$((index + 1)); done
  index=0
  while [ "$index" -lt "$empty" ]; do bar="${bar}░"; index=$((index + 1)); done
  printf '%b%s%b  %s%%\n' "$SETUP_PURPLE" "$bar" "$SETUP_RESET" "$((PROGRESS_CURRENT * 100 / PROGRESS_TOTAL))"
}

progress_done() {
  local elapsed
  elapsed=$(($(date +%s) - PROGRESS_STAGE_STARTED))
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '  %b✓%b Previewed %b(%ss)%b\n' "$SETUP_GREEN" "$SETUP_RESET" "$SETUP_DIM" "$elapsed" "$SETUP_RESET"
  else
    printf '  %b✓%b Complete %b(%ss)%b\n' "$SETUP_GREEN" "$SETUP_RESET" "$SETUP_DIM" "$elapsed" "$SETUP_RESET"
  fi
}

progress_failed() {
  local code="$1" line="$2"
  trap - ERR
  printf '\n%b✗ %s failed%b near line %s (exit %s).\n' "$SETUP_RED" "$PROGRESS_STAGE_NAME" "$SETUP_RESET" "$line" "$code" >&2
  if [ -n "${SETUP_LOG_FILE:-}" ] && [ "${DRY_RUN:-0}" != 1 ]; then
    printf '  Detailed log: %s\n' "$SETUP_LOG_FILE" >&2
    printf '  Setup is idempotent; correct the problem and rerun the same command.\n' >&2
  fi
  exit "$code"
}

progress_finish() {
  local state_dir latest_dotfiles latest_macos
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '\n%b╭─ Dry-run complete ─────────────────────────────────────────╮%b\n' "$SETUP_PURPLE" "$SETUP_RESET"
    printf '  %s stage(s) previewed; no machine changes were made.\n' "$PROGRESS_CURRENT"
  else
    printf '\n%b╭─ Setup complete ───────────────────────────────────────────╮%b\n' "$SETUP_GREEN" "$SETUP_RESET"
    printf '  %b✓%b %s stage(s) finished successfully.\n' "$SETUP_GREEN" "$SETUP_RESET" "$PROGRESS_CURRENT"
  fi
  if [ "${DRY_RUN:-0}" != 1 ]; then
    printf 'Detailed log: %s\n' "$SETUP_LOG_FILE"
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
    run sudo "$@"
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
