# History setup
setopt share_history
setopt hist_expire_dups_first
setopt hist_reduce_blanks   # remove superfluous blanks from history items
setopt inc_append_history   # save history entries as soon as they are entered
setopt hist_ignore_all_dups # ignore duplicate entries
setopt hist_save_no_dups    # do not save duplicate entries
setopt hist_ignore_space    # ignore commands that start with a space
setopt auto_list            # automatically list choices on ambiguous completion
setopt auto_menu            # automatically use menu completion
setopt always_to_end        # move cursor to end if word had one match

# Native prefix-aware history search; no plugin manager required.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# completion using tab
bindkey '^I' expand-or-complete-prefix

# Set prompt editiing to vi mode
set -o vi

zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
