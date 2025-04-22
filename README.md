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

This setup uses a template-based approach for the Claude Desktop configuration to securely manage API credentials.

1. Create a `.env` file in the `~/.dotfiles/claude/` directory with your credentials:
   ```bash
   # ~/.dotfiles/claude/.env
   BLUESKY_IDENTIFIER=your_bluesky_username
   BLUESKY_APP_PASSWORD=your_bluesky_app_password
   # Add any other environment variables needed for templates
   ```

2. Run the hydration script to generate the final configuration:
   ```bash
   cd ~/.dotfiles/claude
   ./hydrate.py
   ```

3. The script will automatically populate the template with your environment variables and generate the final configuration file at `~/Library/Application Support/Claude/claude_desktop_config.json`

This approach allows you to keep sensitive credentials out of your git repository while still tracking the configuration template.

### Requirements for Hydration Script

The script requires:
- Python 3.10+
- Required packages: python-dotenv, jinja2 (installed automatically with uv)

## Utility Scripts

The `bin` directory contains utility scripts:

- `rwbench`: Disk read/write benchmark utility
  - TODO: Add `--help` documentation
- `theme-switch`: Theme switcher for zsh
  - TODO: Add `--help` documentation
