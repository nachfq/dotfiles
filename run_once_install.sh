#!/usr/bin/env bash
set -euo pipefail

echo "Installing core dev deps (zsh, git, curl, tmux, fd, nvim, fonts)..."

if ! sudo apt update; then
  echo "WARN: apt update failed. Continuing..."
fi

sudo apt install -y \
  zsh \
  git \
  curl \
  tmux \
  fd-find \
  libfuse2 \
  unzip \
  fontconfig \
  || true

# Debian/Ubuntu/Mint: binary is often "fdfind" not "fd"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  echo "Creating fd -> fdfind symlink..."
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# --- Install neovim (AppImage) ---
NVIM_VER="0.10.4"
NVIM_URL="https://github.com/neovim/neovim/releases/download/v${NVIM_VER}/nvim-linux-x86_64.appimage"

echo "Installing nvim v${NVIM_VER}..."
mkdir -p "$HOME/.local/bin"
curl -L -o "$HOME/.local/bin/nvim" "$NVIM_URL"
chmod +x "$HOME/.local/bin/nvim"

# --- Install JetBrainsMono Nerd Font (for devicons) ---
if ! fc-list | grep -qi "JetBrainsMono Nerd Font"; then
  echo "Installing JetBrainsMono Nerd Font..."
  mkdir -p "$HOME/.local/share/fonts"
  tmpdir="$(mktemp -d)"
  curl -L -o "$tmpdir/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  unzip -o "$tmpdir/JetBrainsMono.zip" -d "$HOME/.local/share/fonts" >/dev/null
  rm -rf "$tmpdir"
  fc-cache -f >/dev/null
fi

# --- Install fzf (official version, not apt) ---
if [ ! -d "$HOME/.fzf" ]; then
  echo "Installing fzf (official)..."
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-update-rc
fi

echo "Done."
