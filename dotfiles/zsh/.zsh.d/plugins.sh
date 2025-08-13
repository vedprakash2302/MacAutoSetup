# Created by Zap Installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

plug "zsh-users/zsh-autosuggestions"
plug "zap-users/zsh-syntax-highlighting"
plug "wintermi/zsh-brew"
plug "MichaelAquilina/zsh-you-should-use"
plug "wintermi/zsh-starship"
plug "zap-zsh/exa"
plug "zap-zsh/completions"
plug "zsh-users/zsh-history-substring-search"

# Install tmux plugin manager
[ -f "$HOME/.tmux/plugins/tpm" ] && git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm

# ZSH history substring search
