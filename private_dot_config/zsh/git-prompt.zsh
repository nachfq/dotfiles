# Git prompt (RPROMPT): (branch!+) + optional ↑N↓M
autoload -Uz vcs_info add-zsh-hook

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' unstagedstr '!'
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' formats ' %F{180}%b%u%c%f'
zstyle ':vcs_info:git:*' actionformats ' %F{203}%b|%a%u%c%f'

_git_ahead_behind() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  command git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1 || return 0

  local ahead behind
  IFS=$'\t' read -r ahead behind <<<"$(command git rev-list --left-right --count HEAD...@{u} 2>/dev/null)" || return 0

  local out=""
  [[ "$ahead"  != 0 ]] && out+="↑$ahead"
  [[ "$behind" != 0 ]] && out+="↓$behind"
  print -r -- "$out"
}

_git_untracked() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  command git ls-files --others --exclude-standard 2>/dev/null | head -n 1 | read -r _ || return 0
  print -r -- "?"
}

_precmd_git_prompt() {
  vcs_info
  local ab ut
  ab="$(_git_ahead_behind)"
  ut="$(_git_untracked)"

  # si hay untracked, lo mostramos pegado a la info del branch
  local base="${vcs_info_msg_0_}"
  [[ -n "$ut" ]] && base="${base}%F{180}${ut}%f"

  if [[ -n "$ab" ]]; then
    RPROMPT="${base} %F{187}${ab}%f"
  else
    RPROMPT="${base}"
  fi
}

add-zsh-hook precmd _precmd_git_prompt
