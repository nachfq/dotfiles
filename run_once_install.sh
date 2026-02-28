#!/usr/bin/env bash
set -e

echo "Installing base tools..."

sudo apt update

sudo apt install -y \
  curl \
  git \
  zsh \
  fzf \
  eza \
  tree \
  unzip

# fzf full install (keybindings + completion) without touching rc
if [ ! -d "$HOME/.fzf" ]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install --key-bindings --completion --no-update-rc
fi

echo "Done."
