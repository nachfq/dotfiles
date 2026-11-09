#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}

apply_config() {
  if (( EUID == 0 )); then
    printf 'Run apply as the user who will use the editor, not root.\n' >&2
    exit 1
  fi
  local backup_dir
  backup_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/$(date +%Y%m%d-%H%M%S)-$$"

  link_config() {
    local source=$1 target=$2 label=$3
    if [[ -L "$target" && $(readlink -- "$target") == "$source" ]]; then
      return
    fi
    mkdir -p -- "$(dirname -- "$target")"
    if [[ -e "$target" || -L "$target" ]]; then
      mkdir -p -- "$backup_dir"
      mv -- "$target" "$backup_dir/$label"
      printf 'Backed up %s to %s/%s\n' "$target" "$backup_dir" "$label"
    fi
    ln -s -- "$source" "$target"
    printf 'Linked %s\n' "$target"
  }

  link_config "$repo_dir/config/nvim" "$config_dir/nvim" nvim
  # Link only config files: Herdr sockets, sessions and logs stay where they are.
  link_config "$repo_dir/config/herdr/config.toml" "$config_dir/herdr/config.toml" herdr-config.toml
  link_config "$repo_dir/config/herdr/helpers" "$config_dir/herdr/helpers" herdr-helpers
  link_config "$repo_dir/config/bash/worktrees.bash" "$config_dir/bash/worktrees.bash" worktrees.bash
  link_config "$repo_dir/config/bash/interactive.bash" "$config_dir/bash/interactive.bash" interactive.bash
  link_config "$repo_dir/config/bash/gh-headless" "$config_dir/bash/gh-headless" gh-headless
  link_config "$repo_dir/config/bash/inputrc" "$config_dir/bash/inputrc" inputrc
  link_config "$repo_dir/config/starship.toml" "$config_dir/starship.toml" starship.toml
  local source_line='[[ -r "${XDG_CONFIG_HOME:-$HOME/.config}/bash/interactive.bash" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/bash/interactive.bash"'
  if ! grep -Fqx -- "$source_line" "$HOME/.bashrc" 2>/dev/null; then
    if [[ -e "$HOME/.bashrc" ]]; then
      mkdir -p -- "$backup_dir"
      cp -p -- "$HOME/.bashrc" "$backup_dir/bashrc"
      printf 'Backed up .bashrc to %s/bashrc\n' "$backup_dir"
    fi
    printf '\n# Shared development shell configuration\n%s\n' "$source_line" >> "$HOME/.bashrc"
  fi
  printf 'Applied configuration. Open a new Bash shell to load the prompt and shell helpers.\n'
}

prepare_spelling() (
  # English ships with Neovim; download the Spanish files to its user runtime.
  # Keep partial downloads out of the runtime directory if the connection fails.
  local spell_dir="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/site/spell"
  local temp_dir extension file
  temp_dir=$(mktemp -d)
  trap 'rm -r -- "$temp_dir"' EXIT
  mkdir -p -- "$spell_dir"
  for extension in spl sug; do
    file="es.utf-8.$extension"
    if [[ ! -s "$spell_dir/$file" ]]; then
      curl --fail --silent --show-error --location --retry 3 \
        "https://ftp.nluug.nl/pub/vim/runtime/spell/$file" -o "$temp_dir/$file"
      mv -- "$temp_dir/$file" "$spell_dir/$file"
    fi
  done
)

case "${1:-apply}" in
  apply) apply_config ;;
  plugins)
    command -v nvim >/dev/null || { printf 'Install Neovim first.\n' >&2; exit 1; }
    if (( EUID == 0 )); then
      printf 'Run plugins as the user who will use the editor, not root.\n' >&2
      exit 1
    fi
    prepare_spelling
    # A clean Lazy bootstrap can rewrite the lockfile before :Lazy restore runs.
    # Seed its in-memory lock from the original snapshot, then restore that file.
    nvim_lock=$(mktemp)
    cp "$repo_dir/config/nvim/lazy-lock.json" "$nvim_lock"
    trap 'cp "$nvim_lock" "$repo_dir/config/nvim/lazy-lock.json"; rm -- "$nvim_lock"' EXIT
    DOTFILES_NVIM_LOCKFILE="$nvim_lock" DOTFILES_NVIM_SETUP="$repo_dir/scripts/prepare-nvim.lua" \
      nvim --headless \
      '+lua local lock = require("lazy.manage.lock"); lock.lock = vim.json.decode(table.concat(vim.fn.readfile(vim.env.DOTFILES_NVIM_LOCKFILE), "\n")); lock._loaded = true' \
      '+Lazy! restore' '+lua dofile(vim.env.DOTFILES_NVIM_SETUP)' +qa
    ;;
  -h|--help|help)
    printf "Usage: ./apply.sh [apply|plugins]\nApply versioned configuration, or restore its Neovim plugins.\n"
    ;;
  *) printf "Unknown command: %s\n" "$1" >&2; exit 2 ;;
esac
