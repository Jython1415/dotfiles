" Line numbers configuration
set number relativenumber   " Show both absolute current line number and relative numbers

" Tab settings
set expandtab              " Use spaces instead of tabs
set tabstop=4              " Number of spaces a tab counts for
set shiftwidth=4           " Number of spaces for each step of autoindent

" System clipboard integration
set clipboard=unnamed      " Use system clipboard for yanking and pasting

" Cursor shape configuration
let &t_SI = "\e[6 q"       " Use vertical bar cursor in insert mode
let &t_EI = "\e[2 q"       " Use block cursor in normal mode
