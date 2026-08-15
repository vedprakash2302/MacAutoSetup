#!/usr/bin/env bash

log() { printf '\033[0;32m[setup]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[setup] WARN:\033[0m %s\n' "$*" >&2; }
die() { printf '\033[0;31m[setup] ERROR:\033[0m %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }

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
  local url="$1" expected="$2" output="$3" actual
  run mkdir -p "$(dirname "$output")"
  if [ "${DRY_RUN:-0}" = "1" ]; then
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
