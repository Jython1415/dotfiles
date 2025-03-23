#!/usr/bin/env bash

# Set script to exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Directory where the dotfiles repository is already cloned
DOTFILES_DIR="$HOME/.dotfiles"

# Logging function
log() {
    echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"
}

error() {
    echo -e "${RED}ERROR:${NC} $1"
    exit 1
}

# Check if dotfiles directory exists
if [ ! -d "$DOTFILES_DIR" ]; then
    error "Dotfiles directory not found at $DOTFILES_DIR. Please clone your repository first."
fi

log "Starting dotfiles installation..."

# Install Xcode Command Line Tools
log "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    log "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Please wait for Xcode Command Line Tools to install and press enter to continue..."
    read
fi

# Install Homebrew
log "Checking for Homebrew..."
if ! command -v brew &> /dev/null; then
    log "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH based on architecture
    if [[ $(uname -m) == "arm64" ]]; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> $HOME/.zprofile
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        echo 'eval "$(/usr/local/bin/brew shellenv)"' >> $HOME/.zprofile
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

# Refresh PATH after Homebrew installation
log "Making brew accessible for subsequent operations..."
if [[ $(uname -m) == "arm64" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    eval "$(/usr/local/bin/brew shellenv)"
fi

# Brew installs
# Function to install and verify a Homebrew package
install_brew_package() {
    local package=$1
    
    log "Installing $package..."
    if brew ls --versions "$package" &>/dev/null; then
        log "$package is already installed."
    else
        brew install "$package"
        
        # Refresh PATH to ensure the tool is accessible
        if [[ $(uname -m) == "arm64" ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
        
        # Verify installation
        if ! command -v "$package" &>/dev/null; then
            log "Warning: $package was installed but may not be in PATH yet."
        else
            log "$package installed and available."
        fi
    fi
}
install_brew_package "fd"
install_brew_package "ripgrep"
install_brew_package "jq"
install_brew_package "tree"
install_brew_package "git-lfs"

# Install Python via pyenv
log "Checking for pyenv..."
if ! command -v pyenv &> /dev/null; then
    log "Installing pyenv..."
    brew install pyenv pyenv-virtualenv
    export PYENV_ROOT="$HOME/.pyenv"
    command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
    eval "$(pyenv init -)"
    LATEST_VERSION=$(pyenv install --list | rg -o "^\s*3\.\d+\.\d+$" | rg -v "a|b|rc|dev|t" | tail -1 | xargs)
    pyenv install $LATEST_VERSION
    pyenv global $LATEST_VERSION
fi

# Install uv if not present
log "Checking for uv..."
if ! command -v uv &> /dev/null; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install tools with uv
log "Installing tools with uv..."
uv tool install files-to-prompt
uv tool install ttok

# Install nvm and node
log "Checking for nvm..."
if [ -d "$HOME/.nvm" ]; then
    log "NVM directory exists, attempting to load NVM..."
    export NVM_DIR="$HOME/.nvm"
    # Source nvm script to make the function available
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    # Verify nvm function is available
    if type nvm &>/dev/null; then
        log "NVM loaded successfully"
    else
        error "NVM directory exists but function could not be loaded"
    fi
else
    log "Installing nvm..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.2/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
fi

# Install node
log "Checking for node..."
if ! command -v node &> /dev/null; then
    log "Installing node..."
    if type nvm &>/dev/null; then
        nvm install node
    else
        error "Cannot install node: NVM function is not available"
    fi
fi

# Install Oh My Zsh
log "Checking for Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "Installing Oh My Zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install iTerm2
log "Checking for iTerm2..."
if [ ! -d "/Applications/iTerm.app" ] && [ ! -d "$HOME/Applications/iTerm.app" ]; then
    log "Installing iTerm2..."
    brew install --cask iterm2
fi

# Create symlinks
log "Creating symlinks..."

# Symlink zsh theme
mkdir -p "$HOME/.oh-my-zsh/custom/themes"
ln -sf "$DOTFILES_DIR/joshua.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/joshua.zsh-theme" 

# Symlink dotfiles
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

# Make sure bin directory is executable
# This is currently commented out because I believe that executable status is stored in the repository
# if [ -d "$DOTFILES_DIR/bin" ]; then
#     find "$DOTFILES_DIR/bin" -type f -exec chmod +x {} \;
#     log "Made bin scripts executable"
# fi

log "Installation complete! Please restart your terminal."
