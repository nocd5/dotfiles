let $PATH = 'C:\Tools\Ruby\bin' . ';' . $PATH
"set encoding=utf-8
set printfont=ARISAKA-fix:h10:cSHIFTJIS
set nowrap
set clipboard=
set number
set tabstop=8
colorscheme nocd5
set background=light
set guioptions+=b
set backupdir=>H:\.vim_backup\
set directory=>H:\.vim_swap\
set list
set tabstop=4
set shiftwidth=4
set listchars=tab:>_,extends:<,trail:-,eol:<
set sidescrolloff=3
set cmdheight=1
set noundofile
set iminsert=0
set imsearch=-1
set expandtab
let chalice_curl_options="-x 127.0.0.1:8080"
" -- key map ---
nnoremap <silent> <ESC> :noh<CR>
map <F3> :e %:p:h<CR>
"map ,/ <C-v>0I// <ESC>
"map ,- <C-v>0I-- <ESC>
map <F5> :e!<CR>
imap <S-TAB> <C-X><C-K>
noremap j gj
noremap k gk
noremap <C-j> j:SynchronizeWindow<CR>
noremap <C-k> k:SynchronizeWindow<CR>

set printoptions=left:5pc,right:5pc,top:3pc,bottom:3pc,header:0

"
" map <TAB> <S-v>>
" map <S-TAB> <S-v><
" imap <M-j> <DOWN>
" imap <M-k> <UP>
" imap <M-h> <LEFT>
" imap <M-l> <RIGHT>
set statusline=%<%f\ %m%r%h%w%{'['.(&fenc!=''?&fenc:&enc).']['.&ff.']'}%=%l,%c%V%8P

command! -nargs=0 Test inoremap gg<S-v><S-g>

" savevers.vim バックアップファイルの設定" savevers.vimのためにパッチモードに
" します
" set patchmode=.clean
" カンマで区切られたバックアップを作成するファイル名です "*.c,*.h,*.vim"
" let savevers_types = "*"
" バックアップファイルが書き込まれるディレクトリです
" ここでは、オプション"backupdir"と同じディレクトリにしています
let savevers_dirs = &backupdir
" バックアップファイルとの比較でウィンドウのサイズを変更する場合は0
" let versdiff_no_resize=1
" ウィンドウのサイズを変更する場合にどれだけの幅までを許可するか
" let versdiff_no_resize=80

source $HOME/vimfiles/my_func.vim
source $HOME/vimfiles/FSort.vim
" command! -range ExpandSerialNumber <line1>,<line2>!ruby "\%HOME\%"/vimfiles/ExpandSerialNumber.rb
command! -nargs=* -range AlignEqual <line1>,<line2>!ruby "\%HOME\%"/vimfiles/AlignEqual.rb <args>

set runtimepath+=~/.vim
" plugins
set runtimepath+=~/vimplugins/migemo
set runtimepath+=~/vimplugins/yankring
set runtimepath+=~/vimplugins/qfixgrep
set runtimepath+=~/vimplugins/mark
set runtimepath+=~/vimplugins/EnhancedCommentify
set runtimepath+=~/vimplugins/neocomplete.vim
set runtimepath+=~/vimplugins/vimproc.vim
source ~/vimplugins/neocomplete.vim/vimrc
set runtimepath+=~/vimplugins/TweetVim
source ~/vimplugins/TweetVim/vimrc
set runtimepath+=~/vimplugins/lightline
source ~/vimplugins/lightline/vimrc
set runtimepath+=~/vimplugins/ExpandSerialNumber.vim
set runtimepath+=~/vimplugins/unite-gvimrgb
set runtimepath+=~/vimplugins/indentLine
source ~/vimplugins/indentLine/vimrc
" set runtimepath+=~/vimplugins/puyo.vim
" set runtimepath+=~/vimplugins/calendar.vim
" source $HOME/vimplugins/calendar.vim/vimrc
" set runtimepath+=~/vimplugins/ctrlp.vim

let g:yankring_default_menu_mode=0
let MyGrep_MenuBar=0
set runtimepath+=~/vimplugins/open-browser.vim
set runtimepath+=~/vimplugins/previm
set runtimepath+=~/vimplugins/java_getset.vim

" Load settings for each location.
augroup vimrc-local
    autocmd!
    au BufNewFile,BufRead *.h,*.c,*.cpp call s:vimrc_local(expand('<afile>:p:h'))
    au BufNewFile,BufRead *.v call s:vimrc_local(expand('<afile>:p:h'))
augroup END

function! s:vimrc_local(loc)
    let files = findfile('.vimrc.local', escape(a:loc, ' ') . ';', -1)
    for i in reverse(filter(files, 'filereadable(v:val)'))
        source `=i`
    endfor
endfunction

" Highlight Zenkaku Space
function! ZenkakuSpace()
  highlight ZenkakuSpace term=undercurl cterm=undercurl gui=undercurl guifg=Red
endfunction

if has('syntax')
    augroup ZenkakuSpace
        autocmd!
        autocmd ColorScheme       * call ZenkakuSpace()
        autocmd VimEnter,WinEnter * match ZenkakuSpace /　/
    augroup END
    call ZenkakuSpace()
endif

au BufNewFile,BufReadPost \[tweetvim\] nnoremap <silent> <leader>S  :<C-u>TweetVimSay<CR>
au FileType * IminsertOff
