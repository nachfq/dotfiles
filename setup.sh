#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}

usage() {
  cat <<'HELP'
Usage: ./setup.sh [apply|install-tools|plugins]

  apply          Link Neovim, Herdr, Starship and Bash configuration.
                 Add a single source line to .bashrc for the shared shell setup.
                 Existing files are backed up before replacement. (Default.)
  install-tools  Install development editor tools on Ubuntu Linux x86_64.
                 Requires root or sudo; does not apply user configuration.
  plugins        Restore Neovim plugins using the tracked lazy-lock.json.

Credentials, project dependencies, Herdr itself and coding agents are separate.
HELP
}

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

install_tools() {
  # shellcheck source=/dev/null
  . /etc/os-release
  if [[ "$ID" != ubuntu || $(uname -m) != x86_64 ]]; then
    printf 'Tool installation currently supports Ubuntu x86_64. Use apply on other systems.\n' >&2
    exit 1
  fi
  local -a root=()
  if (( EUID != 0 )); then
    command -v sudo >/dev/null || { printf 'Run install-tools as root or install sudo.\n' >&2; exit 1; }
    root=(sudo)
  fi
  "${root[@]}" apt-get update -qq
  "${root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
    git curl ca-certificates python3 build-essential unzip xz-utils ripgrep fd-find jq bash-completion eza
  "${root[@]}" install -d /opt /usr/local/bin
  if ! command -v fd >/dev/null; then
    "${root[@]}" ln -s /usr/bin/fdfind /usr/local/bin/fd
  fi

  download_dir=$(mktemp -d)
  trap 'rm -r -- "$download_dir"' EXIT
  fetch() {
    local name=$1 url=$2 checksum=$3
    curl --fail --silent --show-error --location --retry 3 "$url" -o "$download_dir/$name"
    printf '%s  %s\n' "$checksum" "$download_dir/$name" | sha256sum --check --status
  }

  if [[ $(nvim --version 2>/dev/null | sed -n '1p' || true) != 'NVIM v0.12.6' ]]; then
    fetch nvim.tar.gz \
      https://github.com/neovim/neovim/releases/download/v0.12.6/nvim-linux-x86_64.tar.gz \
      474430d53e6264f6d6dd18db42d6dc9df3a1b56ca9e88a325bbf860e1a811d87
    "${root[@]}" tar -xzf "$download_dir/nvim.tar.gz" -C /opt
    "${root[@]}" ln -sfn /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  fi
  if [[ $(tree-sitter --version 2>/dev/null || true) != 'tree-sitter 0.27.1'* ]]; then
    fetch tree-sitter.gz \
      https://github.com/tree-sitter/tree-sitter/releases/download/v0.27.1/tree-sitter-linux-x64.gz \
      d01042f94ba3d6827ddc9788e235f75d8366431be42bdf90ade534d960c98b7d
    gzip -dc "$download_dir/tree-sitter.gz" > "$download_dir/tree-sitter"
    "${root[@]}" install -m 755 "$download_dir/tree-sitter" /usr/local/bin/tree-sitter
  fi
  if [[ $(lazygit --version 2>/dev/null || true) != *'version=0.66.2,'* ]]; then
    fetch lazygit.tar.gz \
      https://github.com/jesseduffield/lazygit/releases/download/v0.66.2/lazygit_0.66.2_linux_x86_64.tar.gz \
      158efc9ddfa1241fab5fb3526bb442c8dc6c4b1904d73213b9e4e93e03c52034
    tar -xzf "$download_dir/lazygit.tar.gz" -C "$download_dir" lazygit
    "${root[@]}" install -m 755 "$download_dir/lazygit" /usr/local/bin/lazygit
  fi
  if [[ $(node --version 2>/dev/null || true) != v24.22.2 ]]; then
    fetch node.tar.xz \
      https://nodejs.org/dist/v24.22.2/node-v24.22.2-linux-x64.tar.xz \
      48cc0e21e048790e54c0cf5749c2725005313d652651c40b7a21feb9697aaf75
    "${root[@]}" tar -xJf "$download_dir/node.tar.xz" -C /opt
    local name
    for name in node npm npx; do
      "${root[@]}" ln -sfn "/opt/node-v24.22.2-linux-x64/bin/$name" "/usr/local/bin/$name"
    done
  fi
  if [[ $(starship --version 2>/dev/null | sed -n '1p' || true) != 'starship 1.27.0' ]]; then
    fetch starship.tar.gz \
      https://github.com/starship/starship/releases/download/v1.27.0/starship-x86_64-unknown-linux-musl.tar.gz \
      10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89
    tar -xzf "$download_dir/starship.tar.gz" -C "$download_dir" starship
    "${root[@]}" install -m 755 "$download_dir/starship" /usr/local/bin/starship
  fi
  printf 'Installed editor tools. Run apply and plugins as your regular user.\n'
}

case "${1:-apply}" in
  apply) apply_config ;;
  install-tools) install_tools ;;
  plugins)
    command -v nvim >/dev/null || { printf 'Install Neovim first.\n' >&2; exit 1; }
    if (( EUID == 0 )); then
      printf 'Run plugins as the user who will use the editor, not root.\n' >&2
      exit 1
    fi
    DOTFILES_NVIM_SETUP="$repo_dir/scripts/prepare-nvim.lua" \
      nvim --headless '+Lazy! restore' '+lua dofile(vim.env.DOTFILES_NVIM_SETUP)' +qa
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
