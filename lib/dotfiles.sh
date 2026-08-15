#!/usr/bin/env bash

backup_target() {
  local target="$1" relative="$2" destination
  destination="$BACKUP_DIR/$relative"
  log "Backing up $target"
  run mkdir -p "$(dirname "$destination")"
  run mv "$target" "$destination"
  BACKUP_OCCURRED=1
}

is_managed_link() {
  local target="$1" source="$2"
  [ -L "$target" ] || return 1
  [ "$target" -ef "$source" ]
}

is_legacy_link() {
  local target="$1" link
  [ -L "$target" ] || return 1
  link="$(readlink "$target")"
  case "$link" in
    *MacAutoSetup/dotfiles/*|*macautosetup/repo/dotfiles/*) return 0 ;;
    *) return 1 ;;
  esac
}

prepare_parent_path() {
  local relative="$1" current="$HOME" part prefix=""
  IFS='/' read -r -a parts <<< "$(dirname "$relative")"
  for part in "${parts[@]}"; do
    [ "$part" = "." ] && continue
    prefix="${prefix:+$prefix/}$part"
    current="$HOME/$prefix"
    if [ -L "$current" ]; then
      if is_legacy_link "$current"; then
        log "Replacing legacy managed directory link $current"
        run unlink "$current"
      else
        backup_target "$current" "$prefix"
      fi
    fi
    run mkdir -p "$current"
  done
}

prepare_package_conflicts() {
  local package="$1" package_dir source relative target
  package_dir="$REPO_ROOT/dotfiles/$package"
  [ -d "$package_dir" ] || die "Dotfile package does not exist: $package"

  while IFS= read -r -d '' source; do
    relative="${source#"$package_dir"/}"
    target="$HOME/$relative"
    prepare_parent_path "$relative"

    if is_managed_link "$target" "$source"; then
      continue
    elif is_legacy_link "$target"; then
      log "Replacing legacy managed link $target"
      run unlink "$target"
    elif [ -e "$target" ] || [ -L "$target" ]; then
      backup_target "$target" "$relative"
    fi
  done < <(find "$package_dir" \( -type f -o -type l \) -print0)
}

setup_dotfiles() {
  local package
  export BACKUP_OCCURRED=0
  BACKUP_DIR="${BACKUP_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/macautosetup/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$}"
  export BACKUP_DIR

  for package in "${STOW_PACKAGES[@]}"; do
    prepare_package_conflicts "$package"
  done

  for package in "${STOW_PACKAGES[@]}"; do
    log "Linking $package dotfiles"
    run stow --no-folding --restow --target="$HOME" --dir="$REPO_ROOT/dotfiles" "$package"
  done
}
