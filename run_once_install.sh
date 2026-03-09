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


mkdir -p "$HOME/.local/bin" "$HOME/.local/opt"

# --- Install latest Node.js LTS + npm (NodeSource) ---
echo "Installing latest Node.js LTS + npm..."
if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
  sudo apt install -y nodejs
else
  echo "Node already present: $(node --version)"
  echo "npm already present: $(npm --version)"
fi

# --- Tree-sitter CLI ---
# Install/upgrade via npm, but NEVER try to install node here.
echo "Installing/upgrading tree-sitter CLI..."
npm install -g tree-sitter-cli
echo "tree-sitter version: $(tree-sitter --version || true)"

# Debian/Ubuntu/Mint: binary is often "fdfind" not "fd"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  echo "Creating fd -> fdfind symlink..."
  mkdir -p "$HOME/.local/bin"
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# --- Install neovim (official tarball, no AppImage/FUSE) ---
echo "Installing latest nvim (tarball)..."
NVIM_DIR="$HOME/.local/opt/nvim"
TMPDIR="$(mktemp -d)"

curl -L --fail -o "$TMPDIR/nvim.tar.gz" \
  "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"

rm -rf "$NVIM_DIR"
tar -xzf "$TMPDIR/nvim.tar.gz" -C "$TMPDIR"
mv "$TMPDIR/nvim-linux-x86_64" "$NVIM_DIR"
ln -sf "$NVIM_DIR/bin/nvim" "$HOME/.local/bin/nvim"

rm -rf "$TMPDIR"
hash -r

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

# --- DevContainer CLI ---
if ! command -v devcontainer >/dev/null 2>&1; then
  echo "Installing DevContainer CLI..."
  curl -fsSL https://raw.githubusercontent.com/devcontainers/cli/main/scripts/install.sh | sh
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.devcontainers/bin/devcontainer" "$HOME/.local/bin/devcontainer"
fi

echo 'To make zsh your default shell, run: chsh -s "$(which zsh)"'
echo "Done."
