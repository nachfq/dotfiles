# Completion UI + colors
zmodload zsh/complist

autoload -Uz compinit
compinit

# LS_COLORS (for completion list colors + ls)
if command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
