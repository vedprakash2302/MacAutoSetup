#!/usr/bin/env bash

set -Eeuo pipefail

printf 'bootstrap-linux.sh is deprecated; forwarding to bin/setup.\n' >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/bin/setup" --profile server "$@"
