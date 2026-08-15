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

  for pin in "$ZSH_AUTOSUGGESTIONS_COMMIT" "$ZSH_SYNTAX_HIGHLIGHTING_COMMIT" \
    "$ZSH_HISTORY_SUBSTRING_SEARCH_COMMIT" "$ZSH_COMPLETIONS_COMMIT" \
    "$ZSH_YOU_SHOULD_USE_COMMIT" "$ZSH_GIT_ALIAS_COMMIT"; do
    [[ "$pin" =~ ^[0-9a-f]{40}$ ]] || fail "invalid Zsh plugin commit pin: $pin"
  done
  pass "Zsh plugin pins"

  for checksum in "$GUM_SHA_LINUX_X64" "$GUM_SHA_LINUX_ARM64" \
    "$GUM_SHA_MACOS_X64" "$GUM_SHA_MACOS_ARM64" \
    "$EZA_SHA_LINUX_X64" "$EZA_SHA_LINUX_ARM64"; do
    [[ "$checksum" =~ ^[0-9a-f]{64}$ ]] || fail "invalid Gum checksum: $checksum"
  done
  pass "interactive UI binary pins"

  grep -Fq 'tap "nikitabobko/tap", trusted: { cask: "aerospace" }' \
    "$REPO_ROOT/profiles/macos/Brewfile.workstation" || fail "Aerospace cask trust is not scoped declaratively"
  grep -Fq 'cask "docker-desktop"' "$REPO_ROOT/profiles/macos/Brewfile.workstation" || \
    fail "workstation bundle does not use the current Docker Desktop cask token"
  grep -Fq 'tap "jorgerojas26/lazysql", trusted: { formula: "lazysql" }' \
    "$REPO_ROOT/profiles/macos/Brewfile.optional" || fail "lazysql formula trust is not scoped declaratively"
  grep -Fq 'tap "FelixKratz/formulae", trusted: { formula: "borders" }' \
    "$REPO_ROOT/profiles/macos/Brewfile.workstation" || fail "Borders formula trust is not scoped declaratively"
  grep -Fq 'brew "FelixKratz/formulae/borders"' "$REPO_ROOT/profiles/macos/Brewfile.workstation" || \
    fail "macOS workstation does not install the Borders dependency used by Aerospace"
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
  [[ "$mac_intel_output" == *"brew install git stow tmux btop eza"* ]] || fail "macOS eza is not routed through Homebrew"
  linux_output="$(HOME="$TEST_ROOT/linux-routing" MACAUTOSETUP_TEST_OS=linux MACAUTOSETUP_TEST_DISTRO=ubuntu \
    MACAUTOSETUP_TEST_ARCH=x64 "$REPO_ROOT/bin/setup" --dry-run --no-shell-change --no-verify --skip-plugins 2>&1)"
  [[ "$linux_output" == *" btop"* ]] || fail "Linux btop is not routed through Mise"
  [[ "$linux_output" == *" carapace"* && "$linux_output" == *"eza_x86_64-unknown-linux-musl.tar.gz"* ]] || \
    fail "eza and Carapace are not installed cross-platform"
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

parallel_and_recovery() {
  local parallel_root="$TEST_ROOT/parallel" index holder_pid source_repo source_commit checkout bad_checkout
  mkdir -p "$parallel_root"
  # shellcheck disable=SC1091
  . "$REPO_ROOT/lib/common.sh"
  DRY_RUN=0

  parallel_task_a() {
    : > "$parallel_root/a"
    for index in {1..100}; do [ -e "$parallel_root/b" ] && return 0; sleep 0.01; done
    return 1
  }
  parallel_task_b() {
    : > "$parallel_root/b"
    for index in {1..100}; do [ -e "$parallel_root/a" ] && return 0; sleep 0.01; done
    return 1
  }
  parallel_task_fail() { return 7; }
  run_parallel_tasks 2 "barrier A|parallel_task_a" "barrier B|parallel_task_b" >/dev/null || \
    fail "independent setup tasks did not actually overlap"
  if run_parallel_tasks 2 "expected failure|parallel_task_fail" "successful peer|parallel_task_a" >/dev/null 2>&1; then
    fail "parallel task failure was not propagated"
  fi

  mkdir -p "$parallel_root/lock-home"
  HOME="$parallel_root/lock-home" bash -c '
    set -Eeuo pipefail
    source "$1"
    DRY_RUN=0
    setup_lock_acquire
    : > "$2"
    while [ ! -e "$3" ]; do sleep 0.02; done
  ' _ "$REPO_ROOT/lib/common.sh" "$parallel_root/lock-ready" "$parallel_root/lock-stop" &
  holder_pid=$!
  for index in {1..100}; do [ -e "$parallel_root/lock-ready" ] && break; sleep 0.01; done
  [ -e "$parallel_root/lock-ready" ] || fail "setup lock holder did not start"
  if HOME="$parallel_root/lock-home" bash -c '
    set -Eeuo pipefail; source "$1"; DRY_RUN=0; setup_lock_acquire
  ' _ "$REPO_ROOT/lib/common.sh" >/dev/null 2>&1; then
    fail "a concurrent Vedup run acquired the same setup lock"
  fi
  : > "$parallel_root/lock-stop"
  wait "$holder_pid"

  mkdir -p "$parallel_root/lock-home/.local/state/macautosetup/setup.lock"
  printf '99999999\n' > "$parallel_root/lock-home/.local/state/macautosetup/setup.lock/pid"
  HOME="$parallel_root/lock-home" bash -c '
    set -Eeuo pipefail; source "$1"; DRY_RUN=0; setup_lock_acquire; setup_lock_release
  ' _ "$REPO_ROOT/lib/common.sh" || fail "stale setup lock was not recovered"

  source_repo="$parallel_root/source.git"
  checkout="$parallel_root/checkout"
  bad_checkout="$parallel_root/bad-checkout"
  git init --quiet "$source_repo"
  git -C "$source_repo" config user.name Vedup-Test
  git -C "$source_repo" config user.email vedup-test@example.invalid
  printf 'pinned\n' > "$source_repo/plugin.zsh"
  git -C "$source_repo" add plugin.zsh
  git -C "$source_repo" commit --quiet -m pinned
  source_commit="$(git -C "$source_repo" rev-parse HEAD)"
  mkdir -p "$checkout.vedup-tmp-stale"
  VEDUP_BENCH_REPO="$REPO_ROOT" VEDUP_RETRY_DELAY=0 bash -c '
    set -Eeuo pipefail
    source_url="$1"; source_revision="$2"; destination="$3"
    setup_repo="$VEDUP_BENCH_REPO"; set --; source "$setup_repo/bin/setup"
    DRY_RUN=0
    sync_git_checkout "$source_url" "$source_revision" "$destination"
  ' _ "file://$source_repo" "$source_commit" "$checkout"
  [ "$(git -C "$checkout" rev-parse HEAD)" = "$source_commit" ] || fail "atomic plugin checkout used the wrong commit"
  [ ! -e "$checkout.vedup-tmp-stale" ] || fail "stale interrupted plugin checkout was not cleaned"
  mv "$source_repo" "$source_repo.offline"
  VEDUP_BENCH_REPO="$REPO_ROOT" VEDUP_RETRY_DELAY=0 bash -c '
    set -Eeuo pipefail
    source_url="$1"; source_revision="$2"; destination="$3"
    setup_repo="$VEDUP_BENCH_REPO"; set --; source "$setup_repo/bin/setup"
    DRY_RUN=0
    sync_git_checkout "$source_url" "$source_revision" "$destination"
  ' _ "file://$source_repo" "$source_commit" "$checkout" || fail "pinned rerun unnecessarily required the network"
  if VEDUP_BENCH_REPO="$REPO_ROOT" VEDUP_RETRY_DELAY=0 bash -c '
    set -Eeuo pipefail
    source_url="$1"; source_revision="$2"; destination="$3"
    setup_repo="$VEDUP_BENCH_REPO"; set --; source "$setup_repo/bin/setup"
    DRY_RUN=0
    sync_git_checkout "$source_url" "$source_revision" "$destination"
  ' _ "file://$source_repo" 0000000000000000000000000000000000000000 "$bad_checkout" >/dev/null 2>&1; then
    fail "invalid plugin revision unexpectedly installed"
  fi
  [ ! -e "$bad_checkout" ] || fail "failed plugin checkout left a partial destination"
  if compgen -G "$bad_checkout.vedup-tmp-*" >/dev/null; then fail "failed plugin checkout left temporary state"; fi
  pass "bounded parallelism, setup locking, retries, and atomic plugin recovery"
}

zsh_features() {
  local test_home="$TEST_ROOT/zsh-features" plugin_root fake_bin output second_output generator_log zsh_version
  plugin_root="$test_home/share/vedup/zsh/plugins"
  fake_bin="$test_home/bin"
  generator_log="$test_home/generators.log"
  zsh_version="$(zsh -fc 'print -r -- $ZSH_VERSION')"
  mkdir -p "$test_home/.zsh.d" "$fake_bin" \
    "$plugin_root/zsh-completions/src" "$plugin_root/git-alias" \
    "$plugin_root/zsh-you-should-use" "$plugin_root/zsh-autosuggestions" \
    "$plugin_root/zsh-history-substring-search" "$plugin_root/zsh-syntax-highlighting"
  for module in "$REPO_ROOT"/dotfiles/zsh/.zsh.d/*.sh; do
    ln -s "$module" "$test_home/.zsh.d/${module##*/}"
  done
  printf 'VEDUP_CUSTOM_MODULE=loaded\n' > "$test_home/.zsh.d/custom.sh"
  printf 'VEDUP_LOCAL_MODULE=loaded\n' > "$test_home/.zshrc.local"
  printf '#compdef vedup-test\n' > "$plugin_root/zsh-completions/src/_vedup-test"
  printf "alias ga='git add'\n" > "$plugin_root/git-alias/git-alias.plugin.zsh"
  printf 'check_alias_usage() { :; }\n' > "$plugin_root/zsh-you-should-use/you-should-use.plugin.zsh"
  printf '_zsh_autosuggest_start() { :; }\n' > "$plugin_root/zsh-autosuggestions/zsh-autosuggestions.zsh"
  printf '%s\n' 'history-substring-search-up() { :; }' 'history-substring-search-down() { :; }' \
    'zle -N history-substring-search-up' 'zle -N history-substring-search-down' \
    > "$plugin_root/zsh-history-substring-search/zsh-history-substring-search.zsh"
  printf '_zsh_highlight() { :; }\nVEDUP_SYNTAX_LOADED=last\n' \
    > "$plugin_root/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nprintf "fzf\\n" >> "$VEDUP_FAKE_GENERATOR_LOG"\nprintf "VEDUP_FZF_LOADED=1\\n"\n' \
    > "$fake_bin/fzf"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nprintf "carapace\\n" >> "$VEDUP_FAKE_GENERATOR_LOG"\nprintf "VEDUP_CARAPACE_LOADED=1\\n"\n' \
    > "$fake_bin/carapace"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nprintf "mise\\n" >> "$VEDUP_FAKE_GENERATOR_LOG"\nprintf "VEDUP_MISE_LOADED=1\\n"\n' \
    > "$fake_bin/mise"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nprintf "zoxide\\n" >> "$VEDUP_FAKE_GENERATOR_LOG"\nprintf "VEDUP_ZOXIDE_LOADED=1\\n"\n' \
    > "$fake_bin/zoxide"
  # shellcheck disable=SC2016
  printf '#!/usr/bin/env bash\nprintf "starship\\n" >> "$VEDUP_FAKE_GENERATOR_LOG"\nprintf "VEDUP_STARSHIP_LOADED=1\\n"\n' \
    > "$fake_bin/starship"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$fake_bin/eza"
  chmod +x "$fake_bin/fzf" "$fake_bin/carapace" "$fake_bin/mise" "$fake_bin/zoxide" \
    "$fake_bin/starship" "$fake_bin/eza"

  # shellcheck disable=SC2016
  output="$(HOME="$test_home" XDG_DATA_HOME="$test_home/share" VEDUP_FAKE_GENERATOR_LOG="$generator_log" \
    PATH="$fake_bin:/usr/bin:/bin" \
    TERM=xterm-256color zsh -fic '
      source "$1"
      [[ "$VEDUP_CUSTOM_MODULE" = loaded && "$VEDUP_LOCAL_MODULE" = loaded ]]
      [[ "$VEDUP_MISE_LOADED" = 1 && "$VEDUP_ZOXIDE_LOADED" = 1 && "$VEDUP_FZF_LOADED" = 1 ]]
      [[ "$VEDUP_CARAPACE_LOADED" = 1 && "$VEDUP_STARSHIP_LOADED" = 1 && "$VEDUP_SYNTAX_LOADED" = last ]]
      (( $+functions[_zsh_autosuggest_start] && $+functions[_zsh_highlight] ))
      (( $+widgets[history-substring-search-up] && $+aliases[ga] && $+functions[check_alias_usage] ))
      [[ "$fpath[1]" = */zsh-completions/src ]]
      [[ "$aliases[ls]" = "eza --group-directories-first --icons=auto" ]]
      print zsh-features-ok
    ' _ "$REPO_ROOT/dotfiles/zsh/.zshrc" 2>&1)"
  [[ "$output" == *"zsh-features-ok"* ]] || fail "modular Zsh feature stack did not load: $output"
  second_output="$(HOME="$test_home" XDG_DATA_HOME="$test_home/share" VEDUP_FAKE_GENERATOR_LOG="$generator_log" \
    PATH="$fake_bin:/usr/bin:/bin" TERM=xterm-256color zsh -fic '
      source "$1"
      [[ "$VEDUP_MISE_LOADED" = 1 && "$VEDUP_ZOXIDE_LOADED" = 1 && "$VEDUP_FZF_LOADED" = 1 ]]
      [[ "$VEDUP_CARAPACE_LOADED" = 1 && "$VEDUP_STARSHIP_LOADED" = 1 ]]
      print zsh-cache-ok
    ' _ "$REPO_ROOT/dotfiles/zsh/.zshrc" 2>&1)"
  [[ "$second_output" == *"zsh-cache-ok"* ]] || fail "cached Zsh integrations did not load: $second_output"
  for generator in mise zoxide fzf carapace starship; do
    [ "$(grep -c "^${generator}$" "$generator_log")" -eq 1 ] || \
      fail "$generator initialization was regenerated during a warm shell"
    zsh -n "$test_home/.cache/vedup/zsh/init/$generator.zsh" || fail "$generator cache is invalid"
  done
  [ -s "$test_home/.cache/vedup/zsh/zcompdump-${zsh_version}" ] || fail "completion cache was not created"
  pass "modular Zsh features and atomic warm-start caches"
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
parallel_and_recovery
zsh_features
macos_settings_safety
release_asset
dotfile_lifecycle
printf '[test] All checks passed. Temporary files: %s\n' "$TEST_ROOT"
