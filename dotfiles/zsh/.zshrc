# Keep startup deterministic: configuration never downloads or installs anything.
zsh_module_dir="$HOME/.zsh.d"

# Environment and completion paths must exist before command initialization.
[[ -r "$zsh_module_dir/env.sh" ]] && source "$zsh_module_dir/env.sh"
[[ -r "$zsh_module_dir/completions.sh" ]] && source "$zsh_module_dir/completions.sh"
[[ -r "$zsh_module_dir/init-cache.sh" ]] && source "$zsh_module_dir/init-cache.sh"

if [[ -o interactive ]]; then
  (( $+functions[vedup_init_completions] )) && vedup_init_completions

  if (( $+functions[vedup_prepare_init_cache] )); then
    vedup_prepare_init_cache mise mise activate zsh
    [[ -r "$VEDUP_INIT_CACHE_FILE" ]] && source "$VEDUP_INIT_CACHE_FILE"
    vedup_prepare_init_cache zoxide zoxide init zsh
    [[ -r "$VEDUP_INIT_CACHE_FILE" ]] && source "$VEDUP_INIT_CACHE_FILE"
    vedup_prepare_init_cache fzf fzf --zsh
    [[ -r "$VEDUP_INIT_CACHE_FILE" ]] && source "$VEDUP_INIT_CACHE_FILE"
    if (( $+commands[carapace] )); then
      export CARAPACE_BRIDGES='zsh'
      vedup_prepare_init_cache carapace carapace _carapace
      [[ -r "$VEDUP_INIT_CACHE_FILE" ]] && source "$VEDUP_INIT_CACHE_FILE"
    fi
    vedup_prepare_init_cache starship starship init zsh
    [[ -r "$VEDUP_INIT_CACHE_FILE" ]] && source "$VEDUP_INIT_CACHE_FILE"
  else
    # A partially linked configuration remains usable, although Vedup's normal
    # installation always provides the cache helper.
    (( $+commands[mise] )) && eval "$(mise activate zsh)"
    (( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
    (( $+commands[fzf] )) && eval "$(fzf --zsh 2>/dev/null)"
    if (( $+commands[carapace] )); then
      export CARAPACE_BRIDGES='zsh'
      source <(carapace _carapace)
    fi
    (( $+commands[starship] )) && eval "$(starship init zsh)"
  fi

  # Load every modular file, including user-added modules, while keeping the
  # early and final modules in their required positions.
  for config_path in "$zsh_module_dir"/*.sh(N); do
    case "${config_path:t}" in
      env.sh|completions.sh|init-cache.sh|plugins.sh) continue ;;
    esac
    source "$config_path"
  done

  [[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
  # Widgets and syntax highlighting must load after every other integration.
  [[ -r "$zsh_module_dir/plugins.sh" ]] && source "$zsh_module_dir/plugins.sh"
fi

unset zsh_module_dir config_path VEDUP_INIT_CACHE_FILE VEDUP_ZSH_REFRESH_CACHE

# Keep the startup file successful when optional local configuration is absent.
true
