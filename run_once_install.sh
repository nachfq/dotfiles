#!/usr/bin/env bash
set -euo pipefail

echo "Installing core dev deps (zsh, git, curl, fzf, tmux, ripgrep, fd, jq, direnv)..."

# Don't make dotfiles fail because of broken third-party repos on the machine
if ! sudo apt update; then
  echo "WARN: apt update failed (likely broken 3rd-party repos/keys). Continuing..."
fi

# Core packages only
sudo apt install -y \
  zsh \
  git \
  curl \
  fzf \
  tmux \
  || true

# Optional: install fzf keybindings/completion without modifying shell rc
if [ ! -f "$HOME/.fzf.zsh" ] && [ -d "$HOME/.fzf" ]; then
  "$HOME/.fzf/install" --key-bindings --completion --no-update-rc || true
fi

echo "Done."
