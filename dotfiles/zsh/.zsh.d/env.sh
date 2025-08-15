# History setup
export HISTFILE=$HOME/.zhistory
export SAVEHIST=100000
export HISTSIZE=100000

# Editor setup
export GIT_EDITOR=nvim
export EDITOR=nvim

# GNU coreutils (ls, cat, etc.)
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
# GNU findutils (find, xargs, etc.)
export PATH="/opt/homebrew/opt/findutils/libexec/gnubin:$PATH"

# Fzf exports
export FZF_DEFAULT_OPTS="--preview 'bat --color=always {}'"
export FZF_DEFAULT_COMMAND="fd --type f"

# Starship config
export STARSHIP_CONFIG="$HOME/.config/starship/gruvbox.toml"
