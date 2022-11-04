map #5 :w:!ptidy %:e! %
" numbering on by default
set number 
" but easy toggle off/on
map #6 :set number! number?
" set line number color
hi LineNr term=underline ctermfg=black ctermbg=Gray guibg=#808080 gui=bold guifg=black
map #3 :syntax off
map #4 :syntax on
syntax on

" always show filename and status bar in blue+white
set laststatus=2
set statusline+=%F
set statusline+=\ col:\ %c,
hi StatusLine ctermbg=white ctermfg=blue

set backspace=indent,eol,start

" small tab size
set ts=2

" so $HOME/.vim/syntax/typescript.vim
au BufRead,BufNewFile *.ts,*.tsx,*.rst setfiletype typescriptreact
autocmd BufRead,BufNewFile *.ts,*.tsx,*.rst set syntax=typescriptreact
