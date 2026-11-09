# Portable terminal behavior shared by Omarchy and Ubuntu environments.
[[ $- == *i* ]] || return

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
if command -v mise >/dev/null; then
  eval "$(mise activate bash)"
fi
if command -v zoxide >/dev/null; then
  eval "$(zoxide init bash)"
fi

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

# Keep GitHub's device login in the container, with clipboard writes forwarded
# through the terminal and a clickable browser URL. Scope the xclip adapter to
# auth commands so other programs keep their normal clipboard behavior.
gh() {
  local helpers="${XDG_CONFIG_HOME:-$HOME/.config}/bash/gh-headless"
  if [[ -e /dev/incus && -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-}
        && ${1:-} == auth && ( ${2:-} == login || ${2:-} == refresh )
        && -x "$helpers/xclip" && -x "$helpers/browser" ]]; then
    PATH="$helpers:$PATH" GH_BROWSER="${GH_BROWSER:-${BROWSER:-$helpers/browser}}" command gh "$@"
  else
    command gh "$@"
  fi
}

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
