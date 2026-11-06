#!/usr/bin/env bash
# Route a navigation chord to Neovim, or focus a neighboring Herdr pane.
set -euo pipefail

case "${1:-}" in
  left) key=ctrl+h ;;
  down) key=ctrl+j ;;
  up) key=ctrl+k ;;
  right) key=ctrl+l ;;
  *) printf 'Expected left, down, up, or right\n' >&2; exit 2 ;;
esac

# Detached custom commands receive the active pane, not the caller's pane.
pane="${HERDR_ACTIVE_PANE_ID:-${HERDR_PANE_ID:-}}"
if [[ -z "$pane" ]]; then
  printf 'Missing Herdr pane context\n' >&2
  exit 1
fi
herdr_bin="${HERDR_BIN_PATH:-herdr}"
info="$("$herdr_bin" pane process-info --pane "$pane")"

# Never guess from the pane title or from a background editor process.
if jq -e '.result.process_info.foreground_processes | type == "array"' <<< "$info" >/dev/null; then
  if jq -e 'any(.result.process_info.foreground_processes[]; .name == "nvim")' <<< "$info" >/dev/null; then
    exec "$herdr_bin" pane send-keys "$pane" "$key"
  fi
  exec "$herdr_bin" pane focus --pane "$pane" --direction "$1"
fi
printf 'Could not determine the foreground process\n' >&2
exit 1
