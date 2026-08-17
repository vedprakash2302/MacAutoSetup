#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

if [ "$(uname -s)" != Darwin ]; then
  printf '[test] macOS application provider validation is macOS-only; skipped\n'
  exit 0
fi

# shellcheck disable=SC1091
. "$REPO_ROOT/lib/apps.sh"
apps_manifest_validate
while IFS=$'\t' read -r scope provider identifier label description; do
  case "$scope" in ''|'#'*) continue ;; esac
  case "$identifier" in
    */*/*)
      tap="${identifier%/*}"
      token="${identifier##*/}"
      repository="${tap#*/}"
      tap_checkout="$TEST_ROOT/${tap//\//-}"
      if [ ! -d "$tap_checkout/.git" ]; then
        retry=0
        until git clone --quiet --depth 1 "https://github.com/${tap%%/*}/homebrew-$repository.git" "$tap_checkout"; do
          retry=$((retry + 1))
          [ "$retry" -lt 3 ] || { printf 'Unavailable Homebrew tap for %s: %s\n' "$label" "$tap" >&2; exit 1; }
          rm -rf "$tap_checkout"
          sleep 2
        done
      fi
      case "$provider" in
        formula) provider_path='/(Formula|HomebrewFormula)/' ;;
        cask) provider_path='/Casks/' ;;
        *) printf 'Unsupported third-party provider: %s\n' "$provider" >&2; exit 1 ;;
      esac
      if ! find "$tap_checkout" -maxdepth 3 -type f -name "$token.rb" -print | grep -Eq "$provider_path"; then
        printf 'Tap exists but does not contain the declared %s token for %s: %s\n' "$provider" "$label" "$identifier" >&2
        exit 1
      fi
      continue
      ;;
    */*)
      printf 'Invalid Homebrew manifest identifier: %s\n' "$identifier" >&2
      exit 1
      ;;
  esac
  case "$provider" in
    formula) HOMEBREW_NO_AUTO_UPDATE=1 brew info --formula "$identifier" >/dev/null ;;
    cask) HOMEBREW_NO_AUTO_UPDATE=1 brew info --cask "$identifier" >/dev/null ;;
    mas) [[ "$identifier" =~ ^[0-9]+$ ]] ;;
  esac
done < "$VEDUP_MACOS_APPS_MANIFEST"

printf '[test] macOS application manifest and official Homebrew tokens are available\n'
