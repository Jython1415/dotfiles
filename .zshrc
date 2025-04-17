# If you come from bash you might have to change your $PATH.
export PATH=$HOME/bin:/usr/local/bin:$HOME/.dotfiles/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="joshua"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
HIST_STAMPS="yyyy-mm-dd"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git virtualenv dirhistory)

# TODO get git info working without having to disable async updates
# - I changed this because git status info was not being included ih the prompt
# - https://claude.ai/chat/a7bde7d6-a233-463a-a795-8d6914a46ca2
zstyle ':omz:alpha:lib:git' async-prompt "false"

source $ZSH/oh-my-zsh.sh
# disable grep aliases
unalias grep 2>/dev/null
unalias egrep 2>/dev/null
unalias fgrep 2>/dev/null

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

export EDITOR=vim
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# Node Version Manager
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# >>> VSCode venv deactivate hook >>>
if [ -f ~/.vscode-python/deactivate ]; then
    source ~/.vscode-python/deactivate
fi
# <<< VSCode venv deactivate hook <<<

# git executable
alias git='/opt/homebrew/bin/git'

# Set default options for `less`
export LESS=FRX

# Created by `pipx` on 2023-11-12 17:51:42
export PATH="$PATH:/Users/Joshua/.local/bin"

# TeX
export PATH="/Library/TeX/texbin:$PATH"

# raco for Magic Racket in VSCode
export PATH="/Applications/Racket v8.11.1/bin:$PATH"

# rbenv initialization
eval "$(rbenv init -)"

# deno setup
. "/Users/Joshua/.deno/env"

# >>> Personal Convenience Aliases and Functions >>>
# Misc.
# Function to run clear with confirmation
clear_with_confirmation() {
  if [[ "$1" == "-y" ]]; then
    command clear
  else
    echo -n "Are you sure you want to clear the screen? (y/n): "
    read response
    if [[ "$response" =~ ^[Yy]$ ]]; then
      command clear
    fi
  fi
}

# Clear screen commands with confirmation
alias c='clear_with_confirmation'
alias clear='clear_with_confirmation'
alias t="type"
alias reload="source ~/.zshrc"
getalias() { alias "$1" | awk -F'=' '{print $2}' | sed "s/^'//;s/'$//" }
alias sizes="du -sch *"
alias caff="caffeinate"
alias mv='mv -i'

# Network
alias getip="curl -s -w '\n' ifconfig.me/ip"

# Git
alias ga="git add --patch"
alias ganpa="git add"
alias gswt="git switch --track"
alias glon="git log --oneline -n"
# Remapping "gs" because I keep using it accidentally
alias ghostscript="/usr/local/bin/gs"
alias gs="gss"

# Navigation
alias ..="cd .."

# grep
alias rgm='tgrep -s rg -m'

# Docker
alias dcb='docker-compose build'
alias dcu='docker-compose up'
alias dcd='docker-compose down'
# <<< Personal Convenience Aliases and Functions <<<
