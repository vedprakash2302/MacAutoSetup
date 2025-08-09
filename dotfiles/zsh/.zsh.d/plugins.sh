# Created by Zap Installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

plug "zsh-users/zsh-autosuggestions"
plug "zap-users/zsh-syntax-highlighting"
plug "wintermi/zsh-brew"
plug "MichaelAquilina/zsh-you-should-use"
plug "wintermi/zsh-starship"
plug "zap-zsh/exa"

autoload -Uz compinit
compinit
