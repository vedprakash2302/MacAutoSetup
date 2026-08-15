#!/usr/bin/env bash

platform_prepare() {
  if ! has brew; then
    local script_path="${TMPDIR:-/tmp}/macautosetup-homebrew-install.sh"
    download_verified \
      "https://raw.githubusercontent.com/Homebrew/install/${HOMEBREW_INSTALL_COMMIT}/install.sh" \
      "$HOMEBREW_INSTALL_SHA256" "$script_path"
    run /bin/bash "$script_path"
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  elif [ "${DRY_RUN:-0}" != "1" ]; then
    die "Homebrew was installed but is not available on PATH."
  fi
}

platform_install_foundations() {
  run brew update
  run brew install git stow tmux btop
  # These upstream releases do not publish Intel macOS artifacts for Mise.
  if [ "$ARCH" = x64 ]; then run brew install fd git-delta; fi
}

platform_install_workstation() {
  run brew bundle --file "$REPO_ROOT/profiles/macos/Brewfile.workstation"
  run "$REPO_ROOT/dotfiles/macos/mas.sh"
}

platform_install_docker() {
  # Docker Desktop is already part of the workstation profile.
  :
}

platform_install_aws_dependencies() { :; }
