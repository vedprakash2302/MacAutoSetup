#!/usr/bin/env bash

set -Eeuo pipefail

# Required Mac App Store applications. Install only IDs that are absent; never
# run a general App Store update as part of safe sync.
if ! installed_ids="$(mas list 2>/dev/null | awk '{print $1}')"; then
  printf 'Vedup could not read the Mac App Store account. Sign in to the App Store, then rerun Safe sync.\n' >&2
  exit 1
fi
grep -Fxq 937984704 <<< "$installed_ids" || mas install 937984704  # Amphetamine
grep -Fxq 1554235898 <<< "$installed_ids" || mas install 1554235898 # Peek
