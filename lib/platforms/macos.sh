#!/usr/bin/env bash

platform_prepare() {
  if ! has brew; then
    local script_dir script_path
    script_dir="$(mktemp -d "${TMPDIR:-/tmp}/vedup-homebrew.XXXXXX")"
    script_path="$script_dir/install.sh"
    download_verified \
      "https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_COMMIT}/install.sh" \
      "$HOMEBREW_INSTALL_SHA256" "$script_path"
    if [ "${DRY_RUN:-0}" = 1 ]; then
      printf '[dry-run] NONINTERACTIVE=1 /bin/bash %q\n' "$script_path"
    else
      NONINTERACTIVE=1 /bin/bash "$script_path"
      rm -rf "$script_dir"
    fi
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ "${DRY_RUN:-0}" != "1" ]; then
    die "Homebrew was installed but is not available on PATH."
  fi

  # macOS Git is owned by Apple Command Line Tools. Vedup deliberately neither
  # installs nor changes Homebrew Git, credential helpers, .gitconfig or Keychain.
  if [ "${DRY_RUN:-0}" != 1 ] && ! xcrun -f git >/dev/null 2>&1; then
    xcode-select --install >/dev/null 2>&1 || true
    die "Apple Command Line Tools are still installing. Complete the macOS prompt, then run Vedup again."
  fi
}

brew_install_missing_formulae() {
  local formula token
  local -a missing=()
  for formula in "$@"; do
    token="${formula##*/}"
    if inventory_package_installed formula "$token"; then :; else missing+=("$formula"); fi
  done
  [ "${#missing[@]}" -gt 0 ] || return 0
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '[dry-run] HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 brew install'
    quote_command "${missing[@]}"
  else
    retry_command 3 2 env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 \
      brew install "${missing[@]}"
  fi
}

brew_bundle_missing_only() {
  local brewfile="$1"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    printf '[dry-run] HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle --no-upgrade --file %q\n' "$brewfile"
  else
    retry_command 3 2 env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_INSTALL_UPGRADE=1 \
      HOMEBREW_BUNDLE_NO_UPGRADE=1 brew bundle --no-upgrade --file "$brewfile"
  fi
}

brew_upgrade_selected_apps() {
  [ "${UPGRADE_APPS:-0}" = 1 ] || [ -n "${VEDUP_SELECTED_APP_UPGRADES:-}" ] || return 0
  local cask token
  local -a casks=(cursor ghostty raycast docker-desktop aerospace font-jetbrains-mono-nerd-font chatgpt zed thebrowsercompany-dia google-chrome shottr jump-desktop hiddenbar logi-options+)
  [ "${WITH_PERSONAL_APPS:-0}" = 1 ] && casks+=(ankerwork caffeine craft flux-app focus warp)
  for cask in "${casks[@]}"; do
    token="${cask##*/}"
    if [ "${UPGRADE_APPS:-0}" != 1 ]; then
      case " ${VEDUP_SELECTED_APP_UPGRADES:-} " in *" $token "*) ;; *) continue ;; esac
    fi
    brew list --cask "$token" >/dev/null 2>&1 || continue
    plan_cask_outdated "$token" || continue
    retry_command 3 2 run env HOMEBREW_NO_AUTO_UPDATE=1 brew upgrade --cask "$token"
  done
}

platform_install_foundations() {
  brew_install_missing_formulae stow tmux btop eza
  # These upstream releases do not publish Intel macOS artifacts for Mise.
  if [ "$ARCH" = x64 ]; then brew_install_missing_formulae fd git-delta; fi
}

platform_install_workstation() {
  brew_bundle_missing_only "$REPO_ROOT/profiles/macos/Brewfile.workstation"
  run "$REPO_ROOT/dotfiles/macos/mas.sh"
  brew_upgrade_selected_apps
}

platform_install_personal_apps() {
  brew_bundle_missing_only "$REPO_ROOT/profiles/macos/Brewfile.optional"
  brew_install_missing_formulae mas
  run "$REPO_ROOT/dotfiles/macos/mas-optional.sh"
  brew_upgrade_selected_apps
}

platform_install_docker() {
  # Docker Desktop is already part of the workstation profile.
  :
}

platform_install_aws_dependencies() { :; }
