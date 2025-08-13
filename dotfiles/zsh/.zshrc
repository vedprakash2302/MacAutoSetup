# Source .sh files in .zsh.d

for config_file in ~/.zsh.d/*.sh; do
  [ -r "$config_file" ] && source "$config_file"
done

# Zsh compinit
autoload -Uz compinit
compinit -u

# Zoxide
eval "$(zoxide init zsh)"

# FZF
eval "$(fzf --zsh)"
