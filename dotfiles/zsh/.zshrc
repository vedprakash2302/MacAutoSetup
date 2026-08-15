# Keep startup deterministic: configuration never downloads or installs anything.
autoload -Uz compinit
compinit

for config_file in env commands aliases functions; do
  config_path="$HOME/.zsh.d/$config_file.sh"
  [[ -r "$config_path" ]] && source "$config_path"
done
unset config_file config_path

(( $+commands[mise] )) && eval "$(mise activate zsh)"
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"
if (( $+commands[fzf] )) && fzf --zsh >/dev/null 2>&1; then
  eval "$(fzf --zsh)"
fi
(( $+commands[starship] )) && eval "$(starship init zsh)"

[[ -r "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Keep the startup file successful when optional local configuration is absent.
true
