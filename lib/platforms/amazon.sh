#!/usr/bin/env bash

amazon_pkg() {
  if has dnf; then sudo_run dnf install -y "$@"
  else sudo_run yum install -y "$@"; fi
}

platform_prepare() {
  # AL2023 deliberately does not enable EPEL; it is not binary-compatible.
  :
}

install_stow_user_local() {
  has stow && return 0
  local build_dir archive
  build_dir="$(mktemp -d)"
  archive="$build_dir/stow.tar.gz"
  download_verified "https://ftp.gnu.org/gnu/stow/stow-${STOW_VERSION}.tar.gz" "$STOW_SHA256" "$archive"
  if [ "${DRY_RUN:-0}" = "1" ]; then return 0; fi
  tar -xzf "$archive" -C "$build_dir"
  (
    cd "$build_dir/stow-${STOW_VERSION}" || exit 1
    ./configure --prefix="$HOME/.local"
    make
    make install
  )
}

platform_install_foundations() {
  amazon_pkg ca-certificates curl git gcc gcc-c++ make perl tar tmux unzip xz zsh
  install_stow_user_local
}

platform_install_workstation() { :; }

platform_install_docker() {
  if [ "${DISTRO_VERSION:-}" = 2 ] && has amazon-linux-extras; then
    sudo_run amazon-linux-extras install -y docker
  else
    amazon_pkg docker
  fi
  sudo_run systemctl enable --now docker
  if [ "$(id -u)" -ne 0 ]; then sudo_run usermod -aG docker "$USER"; fi
}

platform_install_aws_dependencies() { :; }
