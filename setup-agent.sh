#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
config_dir=${XDG_CONFIG_HOME:-$HOME/.config}

usage() {
  cat <<'HELP'
Usage: ./setup-agent.sh [apply|install-client|install-tools|install-runtimes|grant-sudo|install-codex|configure-codex|install-herdr|plugins]

  apply          Link Neovim, Herdr, Starship and Bash configuration.
                 Add a single source line to .bashrc for the shared shell setup.
                 Existing files are backed up before replacement. (Default.)
  install-client  Link the laptop's agent-env command; does not apply configs.
  install-tools  Install development tools and gh on Ubuntu Linux x86_64.
                 Requires root or sudo; does not apply user configuration.
  install-runtimes  Install mise, Node LTS/npm and uv as the regular user.
  grant-sudo     Allow dev to install packages without a password inside Incus.
                 Run as root inside the disposable environment only.
  install-codex  Install/update Codex using the official installer as this user.
  configure-codex  Default Codex to full access without approval prompts (YOLO).
                   Run only inside the disposable agent environment.
  install-herdr  Install/update Herdr and its Codex status integration as this user.
  plugins        Restore Neovim plugins, tools, parsers and Spanish spelling files.

Logins and project dependencies are configured separately.
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
    git curl ca-certificates python3 build-essential unzip xz-utils ripgrep fd-find jq bash-completion eza bubblewrap apparmor \
    fzf bat zoxide btop rsync pkgconf sudo openssh-server
  "${root[@]}" install -m 644 "$repo_dir/config/apparmor/dotfiles-bwrap" /etc/apparmor.d/dotfiles-bwrap
  "${root[@]}" /sbin/apparmor_parser -r /etc/apparmor.d/dotfiles-bwrap
  "${root[@]}" install -d /opt /usr/local/bin
  if ! command -v fd >/dev/null; then
    "${root[@]}" ln -s /usr/bin/fdfind /usr/local/bin/fd
  fi
  if ! command -v bat >/dev/null; then
    "${root[@]}" ln -s /usr/bin/batcat /usr/local/bin/bat
  fi

  download_dir=$(mktemp -d)
  trap 'rm -r -- "$download_dir"' EXIT
  fetch() {
    local name=$1 url=$2 checksum=$3
    curl --fail --silent --show-error --location --retry 3 "$url" -o "$download_dir/$name"
    printf '%s  %s\n' "$checksum" "$download_dir/$name" | sha256sum --check --status
  }

  if ! command -v dua >/dev/null; then
    fetch dua.tar.gz \
      https://github.com/Byron/dua-cli/releases/download/v3.0.0/dua-v3.0.0-x86_64-unknown-linux-musl.tar.gz \
      59438b0934a521dd4cf2896fa42046023df60e1c25812a07cef913dc2b2d103f
    mkdir "$download_dir/dua"
    tar -xzf "$download_dir/dua.tar.gz" -C "$download_dir/dua"
    local dua_binary
    dua_binary=$(find "$download_dir/dua" -type f -name dua -print -quit)
    "${root[@]}" install -m 755 "$dua_binary" /usr/local/bin/dua
  fi

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
  if [[ $(starship --version 2>/dev/null | sed -n '1p' || true) != 'starship 1.27.0' ]]; then
    fetch starship.tar.gz \
      https://github.com/starship/starship/releases/download/v1.27.0/starship-x86_64-unknown-linux-musl.tar.gz \
      10c8eb4cb3b761d9bf59ea828444c2dab36c900b7d69a69e08814b286969df89
    tar -xzf "$download_dir/starship.tar.gz" -C "$download_dir" starship
    "${root[@]}" install -m 755 "$download_dir/starship" /usr/local/bin/starship
  fi
  if [[ $(gh --version 2>/dev/null | sed -n '1p' || true) != 'gh version 2.103.3 '* ]]; then
    fetch gh.tar.gz \
      https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_linux_amd64.tar.gz \
      4c806978ffce1cec70853302a56d70ac6da4f19bae7adca4e1a8ab00633dd91d
    tar -xzf "$download_dir/gh.tar.gz" -C "$download_dir" gh_2.103.3_linux_amd64/bin/gh
    "${root[@]}" install -m 755 "$download_dir/gh_2.103.3_linux_amd64/bin/gh" /usr/local/bin/gh
  fi
  printf 'Installed development tools. Run apply, install-runtimes, install-codex, configure-codex, install-herdr and plugins as your regular user.\n'
}

install_runtimes() {
  if (( EUID == 0 )); then
    printf 'Run install-runtimes as the environment user, not root.\n' >&2
    exit 1
  fi
  curl -fsSL https://mise.run | sh
  curl -LsSf https://astral.sh/uv/install.sh | UV_NO_MODIFY_PATH=1 sh
  export PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$PATH"
  mise use --global node@lts
}

grant_sudo() {
  if (( EUID != 0 )) || [[ ! -d /dev/incus ]]; then
    printf 'Run grant-sudo as root inside an Incus environment.\n' >&2
    exit 1
  fi
  id dev >/dev/null
  local policy
  policy=$(mktemp)
  printf 'dev ALL=(ALL:ALL) NOPASSWD: ALL\n' > "$policy"
  visudo -cf "$policy"
  install -m 440 "$policy" /etc/sudoers.d/90-agent-dev
  rm -- "$policy"
}

install_codex() {
  if (( EUID == 0 )); then
    printf 'Run install-codex as the user who will use Codex, not root.\n' >&2
    exit 1
  fi
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
}

install_herdr() {
  if (( EUID == 0 )); then
    printf 'Run install-herdr as the user who will use Herdr, not root.\n' >&2
    exit 1
  fi
  curl -fsSL https://herdr.dev/install.sh | sh
  "$HOME/.local/bin/herdr" integration install codex
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
  install-client)
    if (( EUID == 0 )); then
      printf 'Run install-client as your laptop user.\n' >&2
      exit 1
    fi
    mkdir -p "$HOME/.local/bin"
    client="$HOME/.local/bin/agent-env"
    if [[ -e "$client" || -L "$client" ]]; then
      [[ -L "$client" && $(readlink "$client") == "$repo_dir/scripts/agent-env.py" ]] || {
        printf 'Existing command at %s; refusing to replace it.\n' "$client" >&2
        exit 1
      }
    else
      ln -s "$repo_dir/scripts/agent-env.py" "$client"
    fi
    ;;
  install-tools) install_tools ;;
  install-runtimes) install_runtimes ;;
  grant-sudo) grant_sudo ;;
  install-codex) install_codex ;;
  configure-codex)
    if (( EUID == 0 )); then
      printf 'Run configure-codex as the user who will use Codex, not root.\n' >&2
      exit 1
    fi
    python3 "$repo_dir/scripts/configure-codex.py"
    ;;
  install-herdr) install_herdr ;;
  plugins)
    command -v nvim >/dev/null || { printf 'Install Neovim first.\n' >&2; exit 1; }
    if (( EUID == 0 )); then
      printf 'Run plugins as the user who will use the editor, not root.\n' >&2
      exit 1
    fi
    prepare_spelling
    DOTFILES_NVIM_SETUP="$repo_dir/scripts/prepare-nvim.lua" \
      nvim --headless '+Lazy! restore' '+lua dofile(vim.env.DOTFILES_NVIM_SETUP)' +qa
    ;;
  -h|--help|help) usage ;;
  *) usage >&2; exit 2 ;;
esac
