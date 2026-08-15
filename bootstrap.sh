#!/usr/bin/env bash

set -Eeuo pipefail

printf 'bootstrap.sh is deprecated; forwarding to bin/setup.\n' >&2
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/bin/setup" "$@"
