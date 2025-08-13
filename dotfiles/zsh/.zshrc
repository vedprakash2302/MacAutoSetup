# Source .sh files in .zsh.d

for config_file in ~/.zsh.d/*.sh; do
  [ -r "$config_file" ] && source "$config_file"
done


# After compinit

# Zoxide
eval "$(zoxide init zsh)"

# FZF
eval "$(fzf --zsh)"
