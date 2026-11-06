# Jump between worktrees belonging to the current Git repository.
_cdworktree_paths() {
  local field
  while IFS= read -r -d '' field; do
    [[ $field == 'worktree '* ]] && printf '%s\0' "${field#worktree }"
  done < <(git worktree list --porcelain -z 2>/dev/null)
}

cdworktree() {
  if (( $# > 1 )); then
    printf 'Uso: cdworktree [nombre o ruta absoluta]\n' >&2
    return 2
  fi
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    printf 'cdworktree: entrá primero a un repositorio Git.\n' >&2
    return 1
  fi

  local path target=${1%/}
  local -a paths matches=()
  mapfile -d '' -t paths < <(_cdworktree_paths)
  for path in "${paths[@]}"; do
    if (( $# == 0 )); then
      printf '%-24s %s\n' "${path##*/}" "$path"
    elif [[ $target == "$path" || $target == "${path##*/}" ]]; then
      matches+=("$path")
    fi
  done
  (( $# == 0 )) && return 0

  case ${#matches[@]} in
    0) printf 'cdworktree: no existe el worktree «%s» en este repo.\n' "$1" >&2; return 1 ;;
    1) builtin cd -- "${matches[0]}" ;;
    *) printf 'Hay varios worktrees con ese nombre; usá la ruta absoluta:\n' >&2
       printf '  %s\n' "${matches[@]}" >&2
       return 1 ;;
  esac
}

# Match letters in order, including inside a name, ignoring case.
_cdworktree_fuzzy_match() {
  local remaining=${1,,} query=${2,,} char i
  for (( i=0; i<${#query}; i++ )); do
    char=${query:i:1}
    [[ $remaining == *"$char"* ]] || return 1
    remaining=${remaining#*"$char"}
  done
  return 0
}

_cdworktree_complete() {
  COMPREPLY=()
  (( COMP_CWORD == 1 )) || return 0
  local path name current=${COMP_WORDS[COMP_CWORD]}
  local -a paths
  local -A counts=()
  mapfile -d '' -t paths < <(_cdworktree_paths)
  for path in "${paths[@]}"; do
    name=${path##*/}
    counts["$name"]=$(( ${counts["$name"]:-0} + 1 ))
  done
  for path in "${paths[@]}"; do
    name=${path##*/}
    if [[ $current == /* ]] || (( ${counts["$name"]} > 1 )); then
      name=$path
    fi
    _cdworktree_fuzzy_match "$name" "$current" && COMPREPLY+=("$name")
  done
  return 0
}
alias cdw='cdworktree'
complete -o filenames -F _cdworktree_complete cdworktree cdw
