#!/usr/bin/env bash

set -Eeuo pipefail

if ! installed_ids="$(mas list 2>/dev/null | awk '{print $1}')"; then
  printf 'Vedup could not read the Mac App Store account. Sign in to the App Store, then rerun Safe sync.\n' >&2
  exit 1
fi
grep -Fxq 1552826194 <<< "$installed_ids" || mas install 1552826194 # MyWallpaper
