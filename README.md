# dotfiles

## Vim

I used [vim-plug](https://junegunn.github.io/vim-plug/) as the package manager.

Installed with the following command:

```bash
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

I ran `:PlugInstall` in Vim afterwards to install the packages.

## Claude Desktop

The `claude_desktop_config.json` file needs to be manually symlinked to its correct location in `Application Support/Claude`.

```bash
ln -s ~/.dotfiles/claude_desktop_config.json ~/Library/Application\ Support/Claude/claude_desktop_config.json
```

I also added a [`huggingface` MCP server](https://github.com/shreyaskarnik/huggingface-mcp-server) that is manually cloned to `~/Documents/_programming`

