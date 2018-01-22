set nocompatible
set modeline
set backspace=2
set showmode
set autoindent
filetype on
filetype plugin on
filetype indent on
if has("autocmd")
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$")
    \| exe "normal! g`\"" | endif
endif

set encoding=utf-8
set termencoding=utf-8

if has('syntax')
  syntax on
endif

colorscheme desert

set ruler
set number

if version >= 700
  set sursorline
endif

set laststatus=2
set statusline=%-3.3n\ %f%(\ %r%)%(\ %#WarningMsg#%m%0*%)%=(%l/%L,\ %c)\ %P\ [%{&encoding}:%{&fileformat}]%(\ %w%)\ %y\

set shortmess+=axr

set showmatch

set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab
set wrapmargin=0

set nohlsearch
set ignorecase
set smartcase
set incsearch

