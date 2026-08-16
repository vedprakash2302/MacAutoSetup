#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
INVENTORY="$TEST_ROOT/inventory.tsv"
: > "$INVENTORY"

for script in "$REPO_ROOT"/bin/* "$REPO_ROOT"/lib/*.sh "$REPO_ROOT"/lib/platforms/*.sh; do
  [ -f "$script" ] && bash -n "$script"
done

for arch in x64 arm64; do
  output="$(HOME="$TEST_ROOT/home-$arch" VEDUP_TEST_INVENTORY_FILE="$INVENTORY" \
    MACAUTOSETUP_TEST_OS=linux MACAUTOSETUP_TEST_DISTRO=amzn MACAUTOSETUP_TEST_DISTRO_VERSION=2023 \
    MACAUTOSETUP_TEST_ARCH="$arch" "$REPO_ROOT/bin/setup" --profile server --dry-run \
      --no-shell-change --no-verify --skip-plugins 2>&1)"
  [[ "$output" == *"dnf install -y"* || "$output" == *"yum install -y"* ]]
  [[ "$output" != *"dnf upgrade"* && "$output" != *"yum update"* ]]
  [[ "$output" == *"Workflow: fresh"* ]]
done

printf '[test] Amazon Linux 2023 provider passed on simulated x64 and arm64 inventories\n'
