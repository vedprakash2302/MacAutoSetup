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

# Use vi editing while retaining explicit completion bindings in insert mode.
bindkey -v
bindkey -M emacs '^I' expand-or-complete-prefix
bindkey -M viins '^I' expand-or-complete-prefix

zstyle ':completion:*:git:*' group-order 'main commands' 'alias commands' 'external commands'
zstyle ':completion:*' format $'\e[2;37mCompleting %d\e[m'
