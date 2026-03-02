# Zsh compinit - load this first before any completions
autoload -Uz compinit
compinit -u

# Source .sh files in .zsh.d
for config_file in ~/.zsh.d/*.sh; do
  [ -r "$config_file" ] && source "$config_file"
done

# Zoxide
eval "$(zoxide init zsh)"

# FZF
eval "$(fzf --zsh)"

. "$HOME/.local/bin/env"
