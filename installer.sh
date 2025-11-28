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
if ! xcode-select -p &>/dev/null; then
	log "Installing Xcode Command Line Tools..."
	xcode-select --install
	echo "Please wait for Xcode Command Line Tools to install and press enter to continue..."
	read
fi

# Install Homebrew
log "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
	log "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# Add Homebrew to PATH based on architecture
	if [[ $(uname -m) == "arm64" ]]; then
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>$HOME/.zprofile
		eval "$(/opt/homebrew/bin/brew shellenv)"
	else
		echo 'eval "$(/usr/local/bin/brew shellenv)"' >>$HOME/.zprofile
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
install_brew_package "fzf"

# Install Python via pyenv
log "Checking for pyenv..."
if ! command -v pyenv &>/dev/null; then
	log "Installing pyenv..."
	brew install pyenv pyenv-virtualenv
	export PYENV_ROOT="$HOME/.pyenv"
	command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
	eval "$(pyenv init -)"
	LATEST_VERSION=$(pyenv install --list | rg -o "^\s*3\.\d+\.\d+$" | rg -v "a|b|rc|dev|t" | tail -1 | xargs)
	pyenv install $LATEST_VERSION
	pyenv global $LATEST_VERSION
fi

# Ensure Python 3.12 is available
log "Checking for Python 3.12..."
if ! pyenv versions | rg -q "3\.12"; then
	# Try to find latest 3.12.x version
	PYTHON_312_VERSION=$(pyenv install --list | rg -o "^\s*3\.12\.\d+$" | rg -v "a|b|rc|dev|t" | tail -1 | xargs)

	if [ -n "$PYTHON_312_VERSION" ]; then
		log "Installing Python $PYTHON_312_VERSION for compatibility with llm tool..."
		pyenv install $PYTHON_312_VERSION
	else
		log "Warning: No Python 3.12.x version found in available versions. The llm tool may fail to install."
	fi
else
	log "Python 3.12 is already installed"
fi

# Install uv if not present
log "Checking for uv..."
if ! command -v uv &>/dev/null; then
	log "Installing uv..."
	curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# Install tools with uv
log "Installing tools with uv..."
uv tool install files-to-prompt
uv tool install ttok
uv tool install strip-tags
uv tool install llm --python 3.12
uv tool install black
uv tool install "huggingface_hub[cli]"

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
if ! command -v node &>/dev/null; then
	log "Installing node..."
	if type nvm &>/dev/null; then
		nvm install node
	else
		error "Cannot install node: NVM function is not available"
	fi
fi

# Install Deno
log "Checking for Deno..."
if ! command -v deno &>/dev/null; then
	log "Installing Deno..."

	# Set DENO_INSTALL to ensure it's installed in the expected location
	export DENO_INSTALL="$HOME/.deno"

	# Install Deno with -y and --no-modify-path flags to:
	# 1. Skip interactive prompts (-y)
	# 2. Avoid modifying PATH (--no-modify-path) since we already have it in .zshrc
	curl -fsSL https://deno.land/install.sh | sh -s -- -y --no-modify-path

	# Verify installation
	if ! command -v deno &>/dev/null; then
		# Try using the direct path if the command isn't found in PATH
		if [ -f "$DENO_INSTALL/bin/deno" ]; then
			log "Deno installed at $DENO_INSTALL/bin/deno but not in PATH yet."
			log "Your current terminal session may need to be restarted to use deno."
		else
			error "Deno installation failed. Please check the logs and try again."
		fi
	else
		log "Deno installed and available in PATH."
	fi
else
	log "Deno is already installed."
fi

# Install pnpm
log "Checking for pnpm..."
if ! command -v pnpm &>/dev/null; then
	log "Installing pnpm..."

	# Install pnpm using the official installation script
	curl -fsSL https://get.pnpm.io/install.sh | sh -

	# Set PNPM_HOME for this session to verify installation
	export PNPM_HOME="$HOME/Library/pnpm"
	case ":$PATH:" in
	*":$PNPM_HOME:"*) ;;
	*) export PATH="$PNPM_HOME:$PATH" ;;
	esac

	# Verify installation
	if ! command -v pnpm &>/dev/null; then
		log "pnpm installed but not immediately available in PATH."
		log "Your current terminal session may need to be restarted to use pnpm."
	else
		log "pnpm installed and available in PATH."
	fi
else
	log "pnpm is already installed."
fi

# Install rust, cargo
log "Checking for cargo..."
if command -v cargo &>/dev/null; then
	log "cargo is already available"
else
	log "Installing rust and cargo..."
	# Download and run the rustup installer script
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
	# Update the current shell environment without needing to restart
	source "$HOME/.cargo/env"

	# Verify Cargo installation
	if command -v cargo &>/dev/null; then
		log "Cargo installation verified successfully"
	else
		error "Cargo was not found in PATH after installation. You may need to restart your terminal and run this script again."
	fi
fi

# Version check to ensure cargo is working properly
if ! cargo --version &>/dev/null; then
	error "Cargo is installed but not functioning properly. Please check your Rust installation."
fi

# Install tools with cargo
log "Installing Rust tools..."
cargo install treegrep

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

# Symlink zsh themes
mkdir -p "$HOME/.oh-my-zsh/custom/themes"
ln -sf "$DOTFILES_DIR/joshua.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/joshua.zsh-theme"
ln -sf "$DOTFILES_DIR/joshua-minimal.zsh-theme" "$HOME/.oh-my-zsh/custom/themes/joshua-minimal.zsh-theme"
log "Regular and minimal themes symlinked successfully"

# Symlink dotfiles
ln -sf "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"
ln -sf "$DOTFILES_DIR/.zshenv" "$HOME/.zshenv"

# Configure global gitignore
ln -sf "$DOTFILES_DIR/.gitignore_global" "$HOME/.gitignore_global"
git config --global core.excludesfile "$HOME/.gitignore_global"
log "Global gitignore configured"

# Make sure bin directory is executable
# This is currently commented out because I believe that executable status is stored in the repository
# if [ -d "$DOTFILES_DIR/bin" ]; then
#     find "$DOTFILES_DIR/bin" -type f -exec chmod +x {} \;
#     log "Made bin scripts executable"
# fi

log "Installation complete! Please restart your terminal."
