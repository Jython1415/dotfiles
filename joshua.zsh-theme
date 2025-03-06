# joshua.zsh-theme - a minimal, informative theme

# Get return code - show on error
local return_code="%(?..%{$fg[red]%}[%?]%{$reset_color%} )"

# Username and hostname
local user_host="%{$fg[cyan]%}%n%{$reset_color%} @ %{$fg[green]%}%m%{$reset_color%}"

# Current directory
local current_dir="%{$fg[yellow]%}%~%{$reset_color%}"

# Git status info
local git_info='$(git_prompt_info)'

# Time display
local time_display="%{$fg[white]%}[%*]%{$reset_color%}"

# Define the prompt format
PROMPT="
${user_host} in ${current_dir} ${git_info} ${time_display} ${return_code}
%{$fg[red]%}$%{$reset_color%} "

# Remove right prompt
RPROMPT=""

# Git prompt styling
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[blue]%}git:%{$fg[magenta]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[red]%} ●%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%} ✓%{$reset_color%}"
