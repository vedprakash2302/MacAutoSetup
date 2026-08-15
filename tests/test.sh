#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"

pass() { printf '[test] PASS: %s\n' "$*"; }
fail() { printf '[test] FAIL: %s\n' "$*" >&2; exit 1; }

syntax_checks() {
  while IFS= read -r script; do bash -n "$script"; done < <(
    find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -print | while IFS= read -r file; do
      [ "$(head -n 1 "$file" 2>/dev/null || true)" = '#!/usr/bin/env bash' ] && printf '%s\n' "$file"
    done
  )
  pass "Bash syntax"

  if command -v shellcheck >/dev/null 2>&1; then
    while IFS= read -r script; do shellcheck -x "$script"; done < <(
      find "$REPO_ROOT" -path "$REPO_ROOT/.git" -prune -o -type f -print | while IFS= read -r file; do
        [ "$(head -n 1 "$file" 2>/dev/null || true)" = '#!/usr/bin/env bash' ] && printf '%s\n' "$file"
      done
    )
    pass "ShellCheck"
  fi

  python3 - <<'PY' "$REPO_ROOT"
import json
import pathlib
import plistlib
import sys
import tomllib

root = pathlib.Path(sys.argv[1])
json.loads((root / "dotfiles/nvim/.config/nvim/lazyvim.json").read_text())
json.loads((root / "dotfiles/cursor/Library/Application Support/Cursor/User/settings.json").read_text())
tomllib.loads((root / "mise.toml").read_text())
with (root / "dotfiles/macos/keyboard-shortcuts.xml").open("rb") as shortcuts:
    plistlib.load(shortcuts)
PY
  pass "JSON, TOML, and plist parsing"

  # shellcheck disable=SC1091
  . "$REPO_ROOT/versions.env"
  for pin in "$TPM_COMMIT" "$TMUX_NAVIGATOR_COMMIT" "$TMUX_RESURRECT_COMMIT" \
    "$TMUX_CONTINUUM_COMMIT" "$TMUX_SENSIBLE_COMMIT" "$TMUX_ONLINE_STATUS_COMMIT" \
    "$TMUX_BATTERY_COMMIT" "$TMUX_CATPPUCCIN_COMMIT"; do
    [[ "$pin" =~ ^[0-9a-f]{40}$ ]] || fail "invalid tmux plugin commit pin: $pin"
  done
  if grep -Eq '@plugin .*#[0-9a-f]{40}' "$REPO_ROOT/dotfiles/tmux/.tmux.conf"; then
    fail "TPM cannot install a commit hash via branch syntax"
  fi
  pass "tmux plugin pins"
}

macos_settings_safety() {
  local core_output opt_in_output server_output
  core_output="$(HOME="$TEST_ROOT/macos-core" MACAUTOSETUP_TEST_OS=macos \
    MACAUTOSETUP_TEST_MACOS_MAJOR=26 "$REPO_ROOT/dotfiles/macos/setup-commands.sh" --dry-run 2>&1)"
  [[ "$core_output" == *"defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true"* ]] || \
    fail "stable settings do not use the expected desktopservices type"
  [[ "$core_output" != *"persistent-apps"* ]] || fail "default settings unexpectedly reset the Dock"
  [[ "$core_output" != *"symbolichotkeys"* ]] || fail "default settings unexpectedly replace shortcuts"
  [[ "$core_output" != *"AppleFnUsageType"* ]] || fail "default settings unexpectedly apply experimental keys"

  opt_in_output="$(HOME="$TEST_ROOT/macos-opt-ins" MACAUTOSETUP_TEST_OS=macos \
    MACAUTOSETUP_TEST_MACOS_MAJOR=26 "$REPO_ROOT/dotfiles/macos/setup-commands.sh" --dry-run \
      --minimal-dock --keyboard-shortcuts --experimental 2>&1)"
  [[ "$opt_in_output" == *"persistent-apps -array"* ]] || fail "minimal Dock option is not applied"
  [[ "$opt_in_output" == *"defaults import com.apple.symbolichotkeys"* ]] || fail "shortcut option is not applied"
  [[ "$opt_in_output" == *"com.apple.AppleMultitouchMouse MouseButtonMode -string TwoButton"* ]] || \
    fail "experimental mouse preference uses an invalid domain or type"
  [[ "$opt_in_output" != *"AppleMultitouchMouse.plist"* ]] || fail "mouse domain incorrectly includes .plist"

  server_output="$(HOME="$TEST_ROOT/macos-server-settings" MACAUTOSETUP_TEST_OS=macos \
    MACAUTOSETUP_TEST_ARCH=arm64 "$REPO_ROOT/bin/setup" --profile server --dry-run \
      --no-shell-change --no-verify --skip-plugins 2>&1)"
  [[ "$server_output" != *"Applying stable per-user macOS preferences"* ]] || \
    fail "server profile unexpectedly applies macOS preferences"

  if HOME="$TEST_ROOT/macos-conflict" MACAUTOSETUP_TEST_OS=macos MACAUTOSETUP_TEST_ARCH=arm64 \
    "$REPO_ROOT/bin/setup" --dry-run --no-macos-defaults --minimal-dock >/dev/null 2>&1; then
    fail "contradictory macOS preference flags were accepted"
  fi
  pass "macOS preference safety and opt-ins"
}

dry_run_matrix() {
  local target os distro arch profile mac_intel_output linux_output
  for target in 'linux ubuntu x64 server' 'linux ubuntu arm64 server' 'linux amzn x64 server' 'linux amzn arm64 server' 'macos macos x64 workstation' 'macos macos arm64 workstation'; do
    read -r os distro arch profile <<< "$target"
    HOME="$TEST_ROOT/dry-$os-$distro-$arch" \
      MACAUTOSETUP_TEST_OS="$os" MACAUTOSETUP_TEST_DISTRO="$distro" MACAUTOSETUP_TEST_ARCH="$arch" \
      "$REPO_ROOT/bin/setup" --profile "$profile" --dry-run --no-shell-change --no-verify --skip-plugins >/dev/null
  done

  mac_intel_output="$(HOME="$TEST_ROOT/mac-intel-routing" MACAUTOSETUP_TEST_OS=macos \
    MACAUTOSETUP_TEST_ARCH=x64 "$REPO_ROOT/bin/setup" --dry-run --no-shell-change --no-verify --skip-plugins 2>&1)"
  [[ "$mac_intel_output" == *"brew install fd git-delta"* ]] || fail "Intel macOS fallback tools are not routed through Homebrew"
  linux_output="$(HOME="$TEST_ROOT/linux-routing" MACAUTOSETUP_TEST_OS=linux MACAUTOSETUP_TEST_DISTRO=ubuntu \
    MACAUTOSETUP_TEST_ARCH=x64 "$REPO_ROOT/bin/setup" --dry-run --no-shell-change --no-verify --skip-plugins 2>&1)"
  [[ "$linux_output" == *" btop"* ]] || fail "Linux btop is not routed through Mise"
  pass "Ubuntu, Amazon Linux, and macOS dry-run matrix"
}

release_asset() {
  local asset="$TEST_ROOT/bootstrap"
  sed -e 's/__RELEASE_REF__/v0.0.0/g' \
    -e 's/__RELEASE_COMMIT__/0000000000000000000000000000000000000000/g' \
    "$REPO_ROOT/bootstrap" > "$asset"
  bash -n "$asset"
  ! grep -q '__RELEASE_' "$asset" || fail "release bootstrap still contains placeholders"
  pass "release bootstrap rendering"
}

dotfile_lifecycle() {
  command -v stow >/dev/null 2>&1 || fail "GNU Stow is required for the lifecycle test"
  local test_home="$TEST_ROOT/home" backup_list first_count second_count zsh_output
  mkdir -p "$test_home"
  printf 'original zsh config\n' > "$test_home/.zshrc"

  HOME="$test_home" "$REPO_ROOT/bin/setup" --dotfiles-only --skip-plugins --no-shell-change --no-verify >/dev/null
  [ -L "$test_home/.zshrc" ] || fail "setup did not link .zshrc"
  backup_list="$test_home/.local/state/macautosetup/backups.list"
  [ -s "$backup_list" ] || fail "setup did not record its conflict backup"
  first_count="$(wc -l < "$backup_list" | tr -d ' ')"

  HOME="$test_home" "$REPO_ROOT/bin/setup" --dotfiles-only --skip-plugins --no-shell-change --no-verify >/dev/null
  second_count="$(wc -l < "$backup_list" | tr -d ' ')"
  [ "$first_count" = "$second_count" ] || fail "idempotent rerun created a spurious backup"

  if command -v zsh >/dev/null 2>&1; then
    zsh_output="$(env HOME="$test_home" ZDOTDIR="$test_home" TERM=xterm-256color zsh -dfc 'source ~/.zshrc' 2>&1)"
    [ -z "$zsh_output" ] || fail "Zsh startup produced output: $zsh_output"
  fi

  HOME="$test_home" "$REPO_ROOT/bin/uninstall" --restore-backup >/dev/null
  [ ! -L "$test_home/.zshrc" ] || fail "uninstall left .zshrc linked"
  [ "$(sed -n '1p' "$test_home/.zshrc")" = 'original zsh config' ] || fail "uninstall did not restore the original .zshrc"
  pass "backup, link, rerun, and restore lifecycle"
}

syntax_checks
dry_run_matrix
macos_settings_safety
release_asset
dotfile_lifecycle
printf '[test] All checks passed. Temporary files: %s\n' "$TEST_ROOT"
