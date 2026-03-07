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


# --- Tree-sitter CLI ---
# Ubuntu's tree-sitter-cli can be too old for nvim-treesitter (missing `tree-sitter build`)
# Install a recent one via npm.
if ! command -v tree-sitter >/dev/null 2>&1; then
  echo "Installing tree-sitter CLI (npm)..."
  # Ensure node + npm exist
  if ! command -v npm >/dev/null 2>&1; then
    sudo apt install -y nodejs npm || true
  fi
  sudo npm install -g tree-sitter-cli
else
  # If tree-sitter exists but is old, upgrade via npm
  echo "tree-sitter already present: $(tree-sitter --version || true)"
  if command -v npm >/dev/null 2>&1; then
    sudo npm install -g tree-sitter-cli
  fi
fi

# Debian/Ubuntu/Mint: binary is often "fdfind" not "fd"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  echo "Creating fd -> fdfind symlink..."
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# --- Install neovim (AppImage) ---
echo "Installing latest nvim (AppImage)..."
mkdir -p "$HOME/.local/bin"

TMP="$(mktemp)"
curl -L --fail -o "$TMP" \
  "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.appimage"

chmod +x "$TMP"
mv "$TMP" "$HOME/.local/bin/nvim"

# --- Install lazygit (GitHub latest release) ---
if ! command -v lazygit >/dev/null 2>&1; then
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  sudo tar xf lazygit.tar.gz -C /usr/local/bin lazygit
fi

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

# --- Install tmux plugin manager (TPM) ---
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "Installing TPM..."
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
  echo "Installing tmux plugins from ~/.tmux.conf..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
fi


echo "Done."
