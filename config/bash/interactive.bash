# Portable terminal behavior shared by Omarchy and Ubuntu environments.
[[ $- == *i* ]] || return

shopt -s histappend checkwinsize
HISTCONTROL=ignoreboth
HISTSIZE=32768
HISTFILESIZE=$HISTSIZE

if [[ ! -v BASH_COMPLETION_VERSINFO && -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi
bind -f "${XDG_CONFIG_HOME:-$HOME/.config}/bash/inputrc"
source "${XDG_CONFIG_HOME:-$HOME/.config}/bash/worktrees.bash"

export EDITOR=nvim
export VISUAL=nvim
if command -v eza >/dev/null; then
  alias ls='eza -lh --group-directories-first --icons=auto'
  alias lsa='ls -a'
  alias lt='eza --tree --level=2 --long --icons --git'
  alias lta='lt -a'
fi
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias g=git
alias h=herdr
n() {
  if (( $# == 0 )); then command nvim .; else command nvim "$@"; fi
}

if [[ ${TERM:-} != dumb ]] && command -v starship >/dev/null && ! declare -F starship_precmd >/dev/null; then
  eval "$(starship init bash)"
fi
