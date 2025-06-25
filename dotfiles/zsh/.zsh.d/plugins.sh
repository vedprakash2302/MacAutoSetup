# Created by Zap Installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zap-zsh/zap-prompt"
plug "zap-users/zsh-syntax-highlighting"
plug "wintermi/zsh-brew"
plug "MichaelAquilina/zsh-you-should-use"

autoload -Uz compinit
compinit
