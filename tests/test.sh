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

  for checksum in "$GUM_SHA_LINUX_X64" "$GUM_SHA_LINUX_ARM64" \
    "$GUM_SHA_MACOS_X64" "$GUM_SHA_MACOS_ARM64"; do
    [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail "invalid Gum checksum: $checksum"
  done
  pass "interactive UI binary pins"

  grep -Fq 'tap "nikitabobko/tap", trusted: { cask: "aerospace" }' \
    "$REPO_ROOT/profiles/macos/Brewfile.workstation" || fail "Aerospace cask trust is not scoped declaratively"
  grep -Fq 'cask "docker-desktop"' "$REPO_ROOT/profiles/macos/Brewfile.workstation" || \
    fail "workstation bundle does not use the current Docker Desktop cask token"
  grep -Fq 'tap "jorgerojas26/lazysql", trusted: { formula: "lazysql" }' \
    "$REPO_ROOT/profiles/macos/Brewfile.optional" || fail "lazysql formula trust is not scoped declaratively"
  pass "Homebrew cask names and scoped tap trust"
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
  local target os distro arch profile mac_intel_output linux_output progress_output no_color_output
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
  progress_output="$(HOME="$TEST_ROOT/progress" MACAUTOSETUP_TEST_OS=linux MACAUTOSETUP_TEST_DISTRO=ubuntu \
    MACAUTOSETUP_TEST_ARCH=x64 "$REPO_ROOT/bin/setup" --profile server --with-docker --dry-run \
      --no-shell-change --no-verify --skip-plugins 2>&1)"
  [[ "$progress_output" == *"[1/8] Preparing the machine"* ]] || fail "friendly progress does not start at the expected stage"
  [[ "$progress_output" == *"[8/8] Finalizing the login shell"* ]] || fail "friendly progress stage count is incorrect"
  [[ "$progress_output" == *"8 stage(s) previewed; no machine changes were made."* ]] || \
    fail "dry-run completion summary is missing or inaccurate"
  no_color_output="$(NO_COLOR=1 HOME="$TEST_ROOT/no-color" MACAUTOSETUP_TEST_OS=linux \
    MACAUTOSETUP_TEST_DISTRO=ubuntu MACAUTOSETUP_TEST_ARCH=x64 "$REPO_ROOT/bin/setup" --profile server \
      --dry-run --no-shell-change --no-verify --skip-plugins 2>&1)"
  if printf '%s' "$no_color_output" | LC_ALL=C grep -q $'\033'; then fail "NO_COLOR output contains ANSI escapes"; fi
  pass "Ubuntu, Amazon Linux, and macOS dry-run matrix"
}

interactive_installer() {
  local mac_output linux_output custom_output
  mac_output="$(MACAUTOSETUP_TEST_OS=macos MACAUTOSETUP_TEST_ARCH=arm64 \
    MACAUTOSETUP_TEST_CHOICES='workstation|no|no|no|no|no|yes' MACAUTOSETUP_NO_GUM_DOWNLOAD=1 \
    MACAUTOSETUP_INSTALLER_PRINT_ARGS=1 "$REPO_ROOT/bin/install" 2>&1)"
  if [[ "$mac_output" != *"Detected: macOS "* ]] || [[ "$mac_output" != *" / arm64"* ]]; then
    fail "interactive installer did not describe the detected Mac"
  fi
  [[ "$mac_output" == *"SETUP_ARGS --profile workstation --macos-defaults"* ]] || \
    fail "recommended Mac selections did not map to stable setup arguments"
  [[ "$mac_output" == *"▲ ADVANCED — Experimental macOS preferences"* ]] || \
    fail "interactive installer does not explain experimental settings"

  linux_output="$(MACAUTOSETUP_TEST_OS=linux MACAUTOSETUP_TEST_ARCH=x64 MACAUTOSETUP_TEST_DISTRO=ubuntu \
    MACAUTOSETUP_TEST_CHOICES='yes|yes|no' MACAUTOSETUP_NO_GUM_DOWNLOAD=1 \
    MACAUTOSETUP_INSTALLER_PRINT_ARGS=1 "$REPO_ROOT/bin/install" 2>&1)"
  [[ "$linux_output" == *"SETUP_ARGS --profile server --with-aws --with-docker --no-shell-change"* ]] || \
    fail "Linux interactive selections did not map to setup arguments"
  [[ "$linux_output" == *"Vedup"* && "$linux_output" == *"Nice to meet you! Let's set your machine up!"* ]] || \
    fail "interactive installer does not show the Vedup welcome"
  [[ "$linux_output" == *"Administrator approval"* && "$linux_output" == *"passwordless when allowed; otherwise one prompt"* ]] || \
    fail "interactive installer does not disclose its sudo approval flow"
  [[ "$linux_output" == *"__     __"* ]] || fail "interactive installer does not show the Vedup ASCII art"
  [[ "$linux_output" == *"That group has root-equivalent control"* ]] || \
    fail "interactive installer does not explain Docker's group side effect"

  custom_output="$(MACAUTOSETUP_TEST_OS=macos MACAUTOSETUP_TEST_ARCH=x64 \
    MACAUTOSETUP_TEST_CHOICES='custom|no|yes|no|no|no|no|yes' MACAUTOSETUP_NO_GUM_DOWNLOAD=1 \
    MACAUTOSETUP_INSTALLER_PRINT_ARGS=1 "$REPO_ROOT/bin/setup" --interactive 2>&1)"
  [[ "$custom_output" == *"SETUP_ARGS --profile server --macos-defaults"* ]] || \
    fail "custom Mac safe-preference selection was not preserved"
  pass "descriptive interactive installer selection mapping"
}

concise_progress() {
  local concise_home="$TEST_ROOT/concise-home" verbose_home="$TEST_ROOT/verbose-home"
  local concise_output verbose_output concise_log activity_output activity_home="$TEST_ROOT/activity-home"
  mkdir -p "$concise_home" "$verbose_home" "$activity_home"

  concise_output="$(HOME="$concise_home" TERM=xterm-256color MACAUTOSETUP_TEST_COMPACT=1 \
    "$REPO_ROOT/bin/setup" --dotfiles-only --skip-plugins --no-shell-change --no-verify 2>&1)"
  [[ "$concise_output" == *"Concise view: full output is being saved"* ]] || \
    fail "concise installation does not identify its detailed log"
  [[ "$concise_output" == *"Setup complete"* ]] || fail "concise installation did not show its completion summary"
  concise_log="$(find "$concise_home/.local/state/macautosetup/logs" -type f -name '*.log' -print -quit)"
  grep -q '\[setup\] Linking zsh dotfiles' "$concise_log" || fail "concise installation did not retain command output"

  activity_output="$(HOME="$activity_home" TERM=xterm-256color MACAUTOSETUP_TEST_COMPACT=1 \
    MACAUTOSETUP_ACTIVITY_INTERVAL=0.05 bash -c '
      set -Eeuo pipefail
      . "$1"
      DRY_RUN=0 VERBOSE=0 PROGRESS_TOTAL=1 PROFILE=test
      progress_init
      progress_header "test machine" "$PROFILE"
      progress_begin "Downloading a large package" "Show recent activity without scrolling."
      printf "large-download-marker\\n"
      sleep 0.2
      progress_done
      progress_finish
    ' _ "$REPO_ROOT/lib/common.sh" 2>&1)"
  [[ "$activity_output" == *"Working ·"* && "$activity_output" == *"large-download-marker"* ]] || \
    fail "concise dashboard does not refresh recent command activity"

  verbose_output="$(HOME="$verbose_home" TERM=xterm-256color MACAUTOSETUP_TEST_COMPACT=1 \
    "$REPO_ROOT/bin/setup" --dotfiles-only --skip-plugins --no-shell-change --no-verify --verbose 2>&1)"
  [[ "$verbose_output" == *"[setup] Linking zsh dotfiles"* ]] || fail "--verbose did not stream command output"
  pass "fixed concise dashboard and verbose output override"
}

administrator_approval() {
  local fake_bin="$TEST_ROOT/fake-sudo-bin" sudo_log="$TEST_ROOT/fake-sudo.log"
  local prompt_log="$TEST_ROOT/fake-sudo-prompt.log" auth_marker="$TEST_ROOT/fake-sudo.auth"
  mkdir -p "$fake_bin"
  # shellcheck disable=SC2016
  printf '%s\n' '#!/usr/bin/env bash' \
    'printf "%s\n" "$*" >> "$MACAUTOSETUP_TEST_SUDO_LOG"' \
    'if [ "${MACAUTOSETUP_TEST_SUDO_MODE:-}" = prompt ] && [ "$*" = "-n true" ] && [ ! -e "$MACAUTOSETUP_TEST_SUDO_AUTH" ]; then exit 1; fi' \
    'if [ "$*" = "-v" ] && [ -n "${MACAUTOSETUP_TEST_SUDO_AUTH:-}" ]; then : > "$MACAUTOSETUP_TEST_SUDO_AUTH"; fi' \
    > "$fake_bin/sudo"
  chmod +x "$fake_bin/sudo"

  PATH="$fake_bin:$PATH" MACAUTOSETUP_TEST_SUDO_LOG="$sudo_log" bash -c '
    set -Eeuo pipefail
    . "$1"
    DRY_RUN=0
    sudo_acquire
    sudo_run /usr/bin/true
    sudo_release
  ' _ "$REPO_ROOT/lib/common.sh" >/dev/null

  grep -Fxq -- '-n true' "$sudo_log" || fail "setup did not probe passwordless sudo with a real command"
  ! grep -Fxq -- '-v' "$sudo_log" || fail "passwordless sudo unnecessarily requested a password"
  grep -Fxq -- '-n /usr/bin/true' "$sudo_log" || fail "privileged commands can still open a hidden prompt"

  PATH="$fake_bin:$PATH" MACAUTOSETUP_TEST_SUDO_LOG="$prompt_log" \
    MACAUTOSETUP_TEST_SUDO_MODE=prompt MACAUTOSETUP_TEST_SUDO_AUTH="$auth_marker" bash -c '
      set -Eeuo pipefail
      . "$1"
      DRY_RUN=0
      sudo_acquire
      sudo_release
    ' _ "$REPO_ROOT/lib/common.sh" >/dev/null
  grep -Fxq -- '-v' "$prompt_log" || fail "password-required sudo did not request visible approval"
  pass "single visible administrator approval and non-interactive sudo"
}

release_asset() {
  local asset="$TEST_ROOT/bootstrap"
  sed -e 's/__RELEASE_REF__/v0.0.0/g' \
    -e 's/__RELEASE_COMMIT__/0000000000000000000000000000000000000000/g' \
    "$REPO_ROOT/bootstrap" > "$asset"
  bash -n "$asset"
  ! grep -q '__RELEASE_' "$asset" || fail "release bootstrap still contains placeholders"
  grep -q 'bin/install' "$asset" || fail "release bootstrap does not route terminal users to the guided installer"
  grep -q -- '--non-interactive' "$asset" || fail "release bootstrap does not preserve an explicit automation path"
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
  find "$test_home/.local/state/macautosetup/logs" -type f -name '*.log' | grep -q . || \
    fail "setup did not retain a detailed installation log"

  if command -v zsh >/dev/null 2>&1; then
    zsh_output="$(env HOME="$test_home" ZDOTDIR="$test_home" TERM=xterm-256color zsh -dfc 'cd; source ~/.zshrc' 2>&1)"
    [ -z "$zsh_output" ] || fail "Zsh startup produced output: $zsh_output"
  fi

  HOME="$test_home" "$REPO_ROOT/bin/uninstall" --restore-backup >/dev/null
  [ ! -L "$test_home/.zshrc" ] || fail "uninstall left .zshrc linked"
  [ "$(sed -n '1p' "$test_home/.zshrc")" = 'original zsh config' ] || fail "uninstall did not restore the original .zshrc"
  pass "backup, link, rerun, and restore lifecycle"
}

syntax_checks
dry_run_matrix
interactive_installer
concise_progress
administrator_approval
macos_settings_safety
release_asset
dotfile_lifecycle
printf '[test] All checks passed. Temporary files: %s\n' "$TEST_ROOT"
