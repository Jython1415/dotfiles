set number relativenumber  " Line number display
set expandtab              " Use spaces instead of tabs
set tabstop=4              " Number of spaces a tab counts for
set shiftwidth=4           " Number of spaces for each step of autoindent
set clipboard=unnamed      " Use system clipboard for yanking and pasting
set autoindent             " Enable autoindent
set smartindent            " Smart indent for Python TODO what is this?
set showmatch              " Show matching brackets
" set mouse=a                " Enable mouse in all modes TODO do I need this?
set wildmenu               " Commnad-line completion
set encoding=utf-8         " Required for coc.nvim in Vim
set updatetime=300         " For a smoother experience

" Disable backup files to avoid issues with language servers
set nobackup
set nowritebackup

" Cursor shape configuration
let &t_SI = "\e[6 q"       " Use vertical bar cursor in insert mode
let &t_EI = "\e[2 q"       " Use block cursor in normal mode

" Filetype-specific settings
" Enable filetype detection
filetype plugin indent on
" Settings
augroup filetype_settings
  autocmd!

  " Python settings
  autocmd FileType python setlocal
      \ tabstop=4
      \ softtabstop=4
      \ shiftwidth=4
      \ expandtab
      \ autoindent
      \ fileformat=unix
      \ colorcolumn=80 " For PEP8

  " Markdown settings
  autocmd FileType markdown setlocal
      \ tabstop=2
      \ softtabstop=2
      \ shiftwidth=2
      \ expandtab
      \ autoindent

  " JSON settings
  autocmd FileType JSON setlocal
      \ tabstop=2
      \ softtabstop=2
      \ shiftwidth=2
      \ expandtab
      \ autoindent
augroup END

" Plugins with Vim-Plug
call plug#begin()

" Theme plugin
Plug 'ayu-theme/ayu-vim'

" Other plugins
Plug 'neoclide/coc.nvim', {'branch': 'release'}  " VSCode-like intellisense
Plug 'tpope/vim-commentary'                      " Code commenting

call plug#end()

" Theme configuration
set termguicolors
let ayucolor="mirage"
colorscheme ayu

" coc.nvim configuration - basic settings
" Tab for trigger completion, completion confirm, snippet expand and jump
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> auto-select the first completion item
inoremap <silent><expr> <cr> coc#pum#visible() ? coc#pum#confirm() : "\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion
inoremap <silent><expr> <c-space> coc#refresh()

" Navigation mappings
nmap <silent> gd <Plug>(coc-definition)
nmap <silent> gy <Plug>(coc-type-definition)
nmap <silent> gi <Plug>(coc-implementation)
nmap <silent> gr <Plug>(coc-references)

" Diagnostic navigation
nmap <silent><nowait> [g <Plug>(coc-diagnostic-prev)
nmap <silent><nowait> ]g <Plug>(coc-diagnostic-next)

" Use K to show documentation in preview window
nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction

autocmd CursorHold * silent call CocActionAsync('highlight') " Symbol highlight
set statusline^=%{coc#status()}%{get(b:,'coc_current_function','')} " Status line
" Symbol renaming
nmap <leader>rn <Plug>(coc-rename)
" Quick fix for current line
nmap <leader>qf <Plug>(coc-fix-current)
" Organize imports command
command! -nargs=0 OR :call CocActionAsync('runCommand', 'editor.action.organizeImport')

