#!/usr/bin/env bash
set -euo pipefail

echo "Installing core dev deps (zsh, git, curl, tmux, fd, unzip, fontconfig)..."

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
  ca-certificates \
  gnupg \
  lsb-release \
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
echo "Installing/upgrading tree-sitter CLI..."
sudo npm install -g tree-sitter-cli
echo "tree-sitter version: $(tree-sitter --version || true)"

# Debian/Ubuntu/Mint: binary is often "fdfind" not "fd"
if command -v fdfind >/dev/null 2>&1 && ! command -v fd >/dev/null 2>&1; then
  echo "Creating fd -> fdfind symlink..."
  ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"
fi

# --- Install Docker Engine + Docker Compose plugin ---
if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker Engine + Compose plugin..."

  sudo install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
  fi

  if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
      https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  fi

  sudo apt update
  sudo apt install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  sudo usermod -aG docker "$USER" || true
else
  echo "Docker already present: $(docker --version)"
  if docker compose version >/dev/null 2>&1; then
    echo "Docker Compose plugin already present: $(docker compose version)"
  else
    echo "Installing missing Docker Compose plugin..."
    sudo apt update
    sudo apt install -y docker-compose-plugin
  fi
fi

# --- Install neovim (official tarball, skip if already installed) ---
if ! command -v nvim >/dev/null 2>&1; then
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
else
  echo "nvim already present: $(nvim --version | head -n 1)"
fi

# --- Install lazygit (GitHub latest release) ---
if ! command -v lazygit >/dev/null 2>&1; then
  echo "Installing lazygit..."
  LAZYGIT_VERSION="$(curl -s https://api.github.com/repos/jesseduffield/lazygit/releases/latest | grep -Po '"tag_name": "v\K[0-9.]+')"
  TMP_LG="$(mktemp -d)"
  curl -Lo "$TMP_LG/lazygit.tar.gz" \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  sudo tar xf "$TMP_LG/lazygit.tar.gz" -C /usr/local/bin lazygit
  rm -rf "$TMP_LG"
fi

# --- Install JetBrainsMono Nerd Font (skip if already installed) ---
if find "$HOME/.local/share/fonts" -type f \( -iname "*JetBrainsMono*Nerd*Font*.ttf" -o -iname "*JetBrainsMono*Nerd*Font*.otf" \) | grep -q .; then
  echo "JetBrainsMono Nerd Font already installed."
else
  echo "Installing JetBrainsMono Nerd Font..."
  mkdir -p "$HOME/.local/share/fonts"
  TMP_FONT="$(mktemp -d)"
  curl -L -o "$TMP_FONT/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
  unzip -o "$TMP_FONT/JetBrainsMono.zip" -d "$HOME/.local/share/fonts" >/dev/null
  rm -rf "$TMP_FONT"
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
  ln -sf "$HOME/.devcontainers/bin/devcontainer" "$HOME/.local/bin/devcontainer"
fi

echo
echo 'To make zsh your default shell, run: chsh -s "$(which zsh)"'
echo "If Docker was just installed, log out/in or run: newgrp docker"
echo "Done."
