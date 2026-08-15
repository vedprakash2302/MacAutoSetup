# History setup
export HISTFILE=$HOME/.zhistory
export SAVEHIST=100000
export HISTSIZE=100000

# User-local tools and the repository-wide Mise configuration.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
export MACAUTOSETUP_ROOT="${MACAUTOSETUP_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/macautosetup/repo}"
[[ -r "$MACAUTOSETUP_ROOT/mise.toml" ]] && export MISE_CONFIG_FILE="$MACAUTOSETUP_ROOT/mise.toml"

if (( $+commands[nvim] )); then
  export GIT_EDITOR=nvim
  export EDITOR=nvim
else
  export GIT_EDITOR=vim
  export EDITOR=vim
fi

# Fzf exports
export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"
export FZF_DEFAULT_COMMAND="fd --type f"

# Starship config
export STARSHIP_CONFIG="$HOME/.config/starship/gruvbox.toml"
