#!/usr/bin/env bash

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MACOS_DRY_RUN=0
MINIMAL_DOCK=0
KEYBOARD_SHORTCUTS=0
EXPERIMENTAL=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) MACOS_DRY_RUN=1 ;;
    --minimal-dock) MINIMAL_DOCK=1 ;;
    --keyboard-shortcuts) KEYBOARD_SHORTCUTS=1 ;;
    --experimental) EXPERIMENTAL=1 ;;
    *) printf 'Unknown macOS settings option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done
export MACOS_DRY_RUN

if [ "${MACAUTOSETUP_TEST_OS:-}" != macos ] && [ "$(uname -s)" != Darwin ]; then
  printf 'macOS settings can only be applied on macOS.\n' >&2
  exit 1
fi

if [ "$MACOS_DRY_RUN" = 1 ]; then
  printf '[dry-run] %q\n' "$SCRIPT_DIR/../../bin/macos-backup"
else
  backup_dir="$("$SCRIPT_DIR/../../bin/macos-backup")"
  trap 'printf "macOS preference application failed. Restore with: %q %q\n" "$SCRIPT_DIR/../../bin/macos-restore" "$backup_dir" >&2' ERR
fi

"$SCRIPT_DIR/settings/core.sh"
[ "$MINIMAL_DOCK" = 1 ] && "$SCRIPT_DIR/settings/minimal-dock.sh"
[ "$KEYBOARD_SHORTCUTS" = 1 ] && "$SCRIPT_DIR/settings/keyboard-shortcuts.sh"
[ "$EXPERIMENTAL" = 1 ] && "$SCRIPT_DIR/settings/experimental.sh"

if [ "$MACOS_DRY_RUN" != 1 ]; then
  if [ "$KEYBOARD_SHORTCUTS" = 1 ] && [ -x /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings ]; then
    /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u || true
  fi
  killall Dock 2>/dev/null || true
  killall Finder 2>/dev/null || true
  killall SystemUIServer 2>/dev/null || true
  trap - ERR
fi
