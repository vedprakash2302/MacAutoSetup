#!/usr/bin/env bash

platform_prepare() {
  sudo_run apt-get update
}

platform_install_foundations() {
  sudo_run apt-get install -y \
    build-essential ca-certificates curl git perl stow tmux unzip xz-utils zsh
}

platform_install_workstation() { :; }

platform_install_docker() {
  sudo_run apt-get install -y docker.io
  if apt-cache show docker-compose-v2 >/dev/null 2>&1; then
    sudo_run apt-get install -y docker-compose-v2
  else
    sudo_run apt-get install -y docker-compose
  fi
  sudo_run systemctl enable --now docker
  if [ "$(id -u)" -ne 0 ]; then sudo_run usermod -aG docker "$USER"; fi
}

platform_install_aws_dependencies() { :; }
