#!/bin/bash
set -e

NVIM_VERSION="${NVIM_VERSION:-stable}"
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- neovim ---
install_nvim_linux() {
    local arch=$(uname -m)
    local url="https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-${arch}.tar.gz"
    curl -fsSL "$url" -o /tmp/nvim.tar.gz
    sudo tar -C /opt -xzf /tmp/nvim.tar.gz
    sudo ln -sf "/opt/nvim-linux-${arch}/bin/nvim" /usr/local/bin/nvim
    rm /tmp/nvim.tar.gz
}

if ! command -v nvim &> /dev/null; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install neovim
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        install_nvim_linux
    fi
fi

# --- deps ---
if command -v apt &> /dev/null; then
    sudo apt install -y ripgrep fd-find git build-essential curl
elif command -v brew &> /dev/null; then
    brew install ripgrep fd git
elif command -v dnf &> /dev/null; then
    sudo dnf install -y ripgrep fd-find git gcc make curl
elif command -v yum &> /dev/null; then
    sudo yum install -y ripgrep fd-find git gcc make curl
fi

# --- symlink config ---
mkdir -p ~/.config
if [ -e ~/.config/nvim ] && [ ! -L ~/.config/nvim ]; then
    mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
fi
ln -sfn "$DOTFILES_DIR/.config/nvim" ~/.config/nvim

# --- plugin install ---
nvim --headless "+Lazy! sync" +qa 2>/dev/null || true

echo "done. open nvim."