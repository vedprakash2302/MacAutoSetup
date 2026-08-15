#!/usr/bin/env bash

set -Eeuo pipefail

printf 'bootstrap-linux-nogit.sh is deprecated; downloading the unified bootstrap.\n' >&2
URL="https://github.com/vedprakash2302/MacAutoSetup/releases/latest/download/bootstrap"
if ! source_text="$(curl -fsSL "$URL")"; then
  source_text="$(curl -fsSL https://raw.githubusercontent.com/vedprakash2302/MacAutoSetup/main/bootstrap)"
fi
exec bash -c "$source_text" -- --profile server "$@"
