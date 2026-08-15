#!/usr/bin/env bash

macos_log() { printf '[macos] %s\n' "$*"; }
macos_warn() { printf '[macos] WARN: %s\n' "$*" >&2; }
macos_die() { printf '[macos] ERROR: %s\n' "$*" >&2; exit 1; }

macos_run() {
  if [ "${MACOS_DRY_RUN:-0}" = 1 ]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

macos_defaults() {
  macos_run defaults write "$@"
  if [ "${MACOS_DRY_RUN:-0}" != 1 ]; then
    local domain="$1" key="$2"
    defaults read "$domain" "$key" >/dev/null 2>&1 || \
      macos_die "Could not verify $domain $key after writing it."
  fi
}

macos_major_version() {
  if [ -n "${MACAUTOSETUP_TEST_MACOS_MAJOR:-}" ]; then
    printf '%s\n' "$MACAUTOSETUP_TEST_MACOS_MAJOR"
  else
    sw_vers -productVersion | awk -F. '{print $1}'
  fi
}

require_supported_macos_internals() {
  local major
  major="$(macos_major_version)"
  case "$major" in
    14|15|26) ;;
    *)
      [ "${MACAUTOSETUP_ALLOW_UNTESTED_MACOS:-0}" = 1 ] || \
        macos_die "Undocumented preferences are untested on macOS $major. Set MACAUTOSETUP_ALLOW_UNTESTED_MACOS=1 to override."
      macos_warn "Applying undocumented preferences on untested macOS $major."
      ;;
  esac
}
