#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$(uname -s)" != Darwin ]; then
  printf '[test] Brewfile provider validation is macOS-only; skipped\n'
  exit 0
fi

for brewfile in "$REPO_ROOT"/profiles/macos/Brewfile.*; do
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle list --all --file "$brewfile" >/dev/null

  while IFS= read -r tap; do
    [ -n "$tap" ] || continue
    repository="${tap#*/}"
    retry=0
    until git ls-remote --exit-code "https://github.com/${tap%%/*}/homebrew-$repository.git" HEAD >/dev/null 2>&1; do
      retry=$((retry + 1))
      [ "$retry" -lt 3 ] || { printf 'Unavailable Homebrew tap: %s\n' "$tap" >&2; exit 1; }
      sleep 2
    done
  done < <(awk -F '"' '/^tap / { print $2 }' "$brewfile")

  while IFS= read -r formula; do
    [ -n "$formula" ] || continue
    case "$formula" in */*) continue ;; esac
    grep -F 'trusted:' "$brewfile" | grep -Fq "formula: \"$formula\"" && continue
    HOMEBREW_NO_AUTO_UPDATE=1 brew info --formula "$formula" >/dev/null
  done < <(awk -F '"' '/^brew / { print $2 }' "$brewfile")

  while IFS= read -r cask; do
    [ -n "$cask" ] || continue
    case "$cask" in */*) continue ;; esac
    HOMEBREW_NO_AUTO_UPDATE=1 brew info --cask "$cask" >/dev/null
  done < <(awk -F '"' '/^cask / { print $2 }' "$brewfile")
done

printf '[test] Brewfile syntax, official tokens, and third-party taps are available\n'
