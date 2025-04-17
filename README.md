# dotfiles

A collection of personal dotfiles for macOS. Includes shell configuration (zsh), editor setup (Vim), custom themes, utility scripts, and Claude Desktop configuration.

## Prerequisites

- macOS system
- Command line tools for Xcode
- Git (for cloning this repository)

## Installation

1. Clone this repository to `~/.dotfiles`:
   ```bash
   git clone [repository-url] ~/.dotfiles
   ```

2. Run the installer script:
   ```bash
   cd ~/.dotfiles
   ./installer.sh
   ```

The installer will:
- Install required tools (Homebrew, Python via pyenv, Node.js via nvm, Rust, etc.)
- Create necessary symlinks
- Set up Oh My Zsh with custom themes

## Shell Configuration

This setup uses zsh with Oh My Zsh and includes:

- Custom themes: a full theme (`joshua.zsh-theme`) and a minimal theme (`joshua-minimal.zsh-theme`)
- Common aliases and functions
- Integration with pyenv, nvm, and cargo

### Theme Switching

You can switch between themes using the included `theme-switch` script:

```bash
# Switch to minimal theme (just red $ prompt)
theme-switch minimal

# Switch to full theme with git status, python env info, etc.
theme-switch full

# After switching, reload your shell:
source ~/.zshrc
```

## Vim

This setup uses [vim-plug](https://junegunn.github.io/vim-plug/) as the package manager.

Installed with the following command:

```bash
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

Run `:PlugInstall` in Vim afterwards to install the packages.

## Claude Desktop

The `claude_desktop_config.json` file needs to be manually symlinked to its correct location in `Application Support/Claude`.

```bash
ln -s ~/.dotfiles/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

## Utility Scripts

The `bin` directory contains utility scripts:

- `rwbench`: Disk read/write benchmark utility
  - TODO: Add `--help` documentation
- `theme-switch`: Theme switcher for zsh
  - TODO: Add `--help` documentation
