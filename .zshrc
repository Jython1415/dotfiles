
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/Joshua/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/Joshua/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/Users/Joshua/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/Joshua/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export EDITOR=/usr/bin/vim
export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"

# The next line updates PATH for the Google Cloud SDK.
if [ -f '/Users/Joshua/Downloads/google-cloud-sdk/path.zsh.inc' ]; then . '/Users/Joshua/Downloads/google-cloud-sdk/path.zsh.inc'; fi

# The next line enables shell command completion for gcloud.
if [ -f '/Users/Joshua/Downloads/google-cloud-sdk/completion.zsh.inc' ]; then . '/Users/Joshua/Downloads/google-cloud-sdk/completion.zsh.inc'; fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


# Load Angular CLI autocompletion.
source <(ng completion script)

# >>> VSCode venv deactivate hook >>>
source ~/.vscode-python/deactivate
# <<< VSCode venv deactivate hook <<<

# git executable
alias git='/opt/homebrew/bin/git'

# Created by `pipx` on 2023-11-12 17:51:42
export PATH="$PATH:/Users/Joshua/.local/bin"

# TeX
export PATH="/Library/TeX/texbin:$PATH"