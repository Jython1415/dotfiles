# joshua.zsh-theme - a minimal, informative theme

# Time display
local time_display="%{$fg[white]%}[%*]%{$reset_color%}"

# Get return code - show on error
local return_code="%(?.. %{$fg[red]%}[%?]%{$reset_color%} )"

# Username and hostname
local user_host="%{$fg[cyan]%}%n%{$reset_color%} @ %{$fg[green]%}%m%{$reset_color%}"

# Current directory
local current_dir="%{$fg[yellow]%}%~%{$reset_color%}"

# Git status info
git_prompt_wrapper() {
    local git_info="$(git_prompt_info)"
    [[ -n "$git_info" ]] && echo " $git_info"
}
local git_info='$(git_prompt_wrapper)'

# Python environment info
env_prompt_wrapper() {
    local venv="$(virtualenv_prompt_info)"
    local conda="$(conda_prompt_info)"
    [[ -n "$venv$conda" ]] && echo " $venv$conda"
}
local env_info='$(env_prompt_wrapper)'

# Define the prompt format
PROMPT="
${time_display} ${user_host} in ${current_dir}${git_info}${env_info}${return_code}
%{$fg[red]%}$%{$reset_color%} "

# Remove right prompt
RPROMPT=""

# Git prompt styling
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[blue]%}git:%{$fg[magenta]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%} ●%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%} ✓%{$reset_color%}"

# Python virtual environment styling
ZSH_THEME_VIRTUAL_ENV_PROMPT_PREFIX=" %{$fg[blue]%}venv:%{$fg[cyan]%}"
ZSH_THEME_VIRTUAL_ENV_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_VIRTUALENV_PREFIX="$ZSH_THEME_VIRTUAL_ENV_PROMPT_PREFIX"
ZSH_THEME_VIRTUALENV_SUFFIX="$ZSH_THEME_VIRTUAL_ENV_PROMPT_SUFFIX"

