set nocompatible
let mapleader = "\<Space>"
if &shell =~# 'fish$'
  set shell=/bin/bash
endif

" {{{ Darwin & Python3
let uname = substitute(system('uname'), '\n', '', '')

let path_install_plug = '/dmitriy/.vim/autoload/plug.vim'
let path_plugged = '/dmitriy/.vim/plugged'
if uname == 'Darwin'
    let path_install_plug = '/Users' . path_install_plug
    let path_plugged = '/Users' . path_plugged
else
    let path_install_plug = '/home' . path_install_plug
    let path_plugged = '/home' . path_plugged
endif
" }}}

" {{{ Plugins

" {{{ Install plug
if empty(glob(path_install_plug))
    execute '!curl -fLo ' path_install_plug '--create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif
" }}}

call plug#begin(path_plugged)

" {{{ UI & appearance
Plug 'https://github.com/itchyny/lightline.vim'
Plug 'https://github.com/Shougo/unite.vim'
Plug 'https://github.com/jubnzv/gruvbox'           " Color scheme
Plug 'https://github.com/arcticicestudio/nord-vim'
Plug 'https://github.com/chrisbra/Colorizer'       " Colorize color names and codes
Plug 'https://github.com/junegunn/vim-peekaboo'    " Shows vim registers content into vertical split
Plug 'https://github.com/Yggdroot/indentLine'      " Show indentation as vertical lines
Plug 'https://github.com/haya14busa/incsearch.vim' " Incrementally highlight search results
Plug 'https://github.com/liuchengxu/vim-which-key' " Display available keybindings in popup
Plug 'https://github.com/jubnzv/vim-cursorword'    " Highlight word under cursor
Plug 'https://github.com/godlygeek/tabular'         " Vim script for text filtering and alignment
Plug 'https://github.com/tpope/vim-surround'
Plug 'https://github.com/MattesGroeger/vim-bookmarks'
Plug 'https://github.com/jiangmiao/auto-pairs'      " Insert or delete brackets, parens, quotes in pair
" }}}

" {{{ Git
Plug 'https://github.com/airblade/vim-gitgutter' 
" }}}

" {{{ Writing code
Plug 'https://github.com/darfink/vim-plist'
Plug 'prurigro/vim-markdown-concealed'
Plug 'masukomi/vim-markdown-folding'
Plug 'rizzatti/dash.vim'
Plug 'https://github.com/terryma/vim-expand-region'    " Visually select increasingly larger regions of text
Plug 'https://github.com/Shougo/echodoc.vim'           " Displays function signatures from completions in the command line
Plug 'https://github.com/scrooloose/nerdcommenter'
Plug 'terryma/vim-multiple-cursors'
Plug 'https://github.com/cespare/vim-toml'
" }}}

" {{{ fzf
Plug 'https://github.com/junegunn/fzf.vim'
Plug 'https://github.com/junegunn/fzf', {
  \ 'dir': '~/.local/opt/fzf',
  \ 'do': './install --all'
  \ }
" }}}

call plug#end()

" }}}

" {{{ General
filetype on
autocmd FileType c setlocal foldmethod=syntax
" setlocal foldmethod=syntax
set viminfo='1000,f1                        " Save global marks for up to 1000 files
set scrolloff=7                             " 7 lines above/below cursor when scrolling
set scroll=7                                " Number of lines scrolled by <C-u> and <C-d>
set undofile
if uname == 'Darwin'
    set undodir=/Users/dmitriy/.vim/undo
else
    set undodir=/home/dmitriy/.vim/undo
endif

set undolevels=1000
set undoreload=10000
set clipboard=unnamedplus,unnamed           " Use system clipboard
set showmatch                               " Show matching brackets when text indicator is over them
set mat=1                                   " How many tenths of a second to blink when matching brackets
set wildmenu                                " wildmenu: command line completion
set wildmode=longest,list
set wildignore=*.o,*~,*.pyc,*.aux,*.out,*.toc
" set wildignore+=*.pyc,*.o,*.obj,*.svn,*.swp,*.class,*.hg,*.DS_Store,*.min.*
set timeoutlen=500                          " Time to wait for a mapped sequence to complete (ms)
" set notimeout                               " Remove delay between complex keybindings.
set ttimeoutlen=0                           " Finally found it, otherwize long exit insert mode, macvim works fine without it
set noautochdir                             " Set working directory to the current file
" set noruler
set autoindent                              " Autoindent when starting new line, or using o or O.
set noautoread                              " Don't reload unchanged files automatically.
set hidden
set tabstop=4
set shiftwidth=4
set expandtab                               " On pressing tab insert 4 spaces

set splitright

" Cyrillic layout in normal mode
set langmap+=ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ
set langmap+=фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz
set langmap+=ЖжЭэХхЪъ;\:\;\"\'{[}]
" }}}

" {{{ UI options
set guioptions-=m                           " Remove menu bar
set guioptions-=T                           " Remove toolbar
set guioptions-=r                           " Remove right-hand scroll bar
set guioptions-=L                           " Remove left-hand scroll bar
set shortmess+=Ic                           " Don't display the intro message on starting vim
set noshowmode
set relativenumber
set cursorline
set laststatus=2                            " Always show status line
set signcolumn=yes
set background=dark
set t_Co=256                                " 256-colors mode
set guicursor+=c-ci-cr:block                " Cursor style
set noswapfile
"" Always show statusline
set laststatus=2

let &t_SI.="\e[5 q" "SI = INSERT mode
let &t_SR.="\e[4 q" "SR = REPLACE mode
let &t_EI.="\e[2 q" "EI = NORMAL mode (ELSE)

" Italic symbols in terminal
set t_ZH=^[[3m
set t_ZR=^[[23m

" Gruvbox configuration
let g:gruvbox_sign_column='bg0'
let g:gruvbox_color_column='bg0'
let g:gruvbox_number_column='bg0'
" colorscheme gruvbox

colorscheme nord

" Not working with macvim 
highlight htmlBold gui=bold guifg=#af0000 ctermfg=124
highlight htmlItalic gui=italic guifg=#af8700 ctermfg=214

let g:indentLine_concealcursor = ''
let g:indentLine_conceallevel = 0

let g:indentLine_char = ''


" let g:indentLine_enabled = 1
" set listchars=tab:\⎸\ 

" set list
" }}}

" {{{ Lightline
if has("gui_running")
    let g:lightline = {
      \ 'colorscheme': 'gruvbox',
      \ 'active': {
      \   'left':  [ [ 'mode', 'paste' ],
      \              [ 'filename', 'modified' ] ],
      \   'right': [ [ 'lineinfo' ],
      \              [ 'percent' ],
      \              [ 'lsp_status' ],
      \              [ 'fileformat', 'fileencoding', 'filetype' ] ],
      \ },
      \ 'component': {
      \   'lineinfo': "%c:%{line('.') . '/' . line('$')}",
      \   'modified': '%{&filetype=="help"?"":&modified?"":&modifiable?"":"\u2757"}',
      \ },
      \ }
else
    let g:lightline = {
      \ 'colorscheme': 'nord',
      \ 'active': {
      \   'left':  [ [ 'mode', 'paste' ],
      \              [ 'filename', 'modified' ] ],
      \   'right': [ [ 'lineinfo' ],
      \              [ 'percent' ],
      \              [ 'lsp_status' ],
      \              [ 'fileformat', 'fileencoding', 'filetype' ] ],
      \ },
      \ 'component': {
      \   'lineinfo': "%c:%{line('.') . '/' . line('$')}",
      \   'modified': '%{&filetype=="help"?"":&modified?"":&modifiable?"":"\u2757"}',
      \ },
      \ }
endif
" }}}

" {{{ Jump to the last position when reopening a file 
" (see `/etc/vim/vimrc`)
au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Insert fold block
let g:surround_102 = split(&commentstring, '%s')[0] . " {{{ \r " . split(&commentstring, '%s')[0] . " }}}"
" }}}

" {{{ Folding settings

" {{{ Folding options
set foldmethod=syntax
set foldnestmax=6
set nofoldenable       " Disable folding when open file
set foldlevel=2
set foldcolumn=0
set fillchars=fold:\ 
" }}}

" }}}

" {{{ Keybindings

" Need to find out if gui running and map <D> to <M>

" {{{ Common
" Binds that changes default vim behavior, separated from plugins
" configuration.
"
map <Leader><ESC> :pclose<CR>:noh<CR>:echo<CR>
nnoremap <ENTER> :pclose<CR>:noh<CR>:echo<CR>

" Insert newline without entering insert mode
nnoremap zj o<Esc>k
nnoremap zk O<Esc>j
nnoremap яо o<Esc>k
nnoremap ял O<Esc>j

" Reload vimrc
nnoremap <leader>R :so $MYVIMRC<CR>:echo "Config reloaded"<CR>
nnoremap <leader>К :so $MYVIMRC<CR>:echo "Config reloaded"<CR>

" Open config files
nnoremap <leader>C :cd ~/.config<CR>:next .bashrc fish/config.fish .vimrc nvim/init.vim karabiner/karabiner.json install.sh .tmux.conf .zshrc<CR>
nnoremap <leader>С :cd ~/.config<CR>:next .bashrc fish/config.fish .vimrc nvim/init.vim karabiner/karabiner.json install.sh .tmux.conf .zshrc<CR>

" Open bookmarks
nnoremap <leader>B :cd ~/OneDrive/Notes<CR>:FZF<CR>
nnoremap <leader>И :cd ~/OneDrive/Notes<CR>:FZF<CR>

" Insert current time
nnoremap <leader>td "=strftime("%x %X")<CR>P
nnoremap <leader>ев "=strftime("%x %X")<CR>P

" Highlight search results incrementally (haya14busa/incsearch.vim)
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" Tabularize
cnoreabbrev Tab Tabularize

" Create new split
inoremap <D-d> <C-o>:vsplit_v<CR>
nnoremap <D-d> :vsplit_v<CR>

"Go to next split
nnoremap <A-w> <C-w><C-W>

" Inserting new line
inoremap <A-ENTER> <C-o>o

" Search highlighted text
vnoremap // y/<C-R>"<CR>

" Delete word in insert (iTerm doesn't recognize 'alt<-delete', mvim use default
" emacs binds)
inoremap <M-BS> <C-o>b<C-o>de

nnoremap <silent><leader>e :e<CR>
nnoremap <silent><leader>у :e<CR>
nnoremap <silent><leader>E :e!<CR>
nnoremap <silent><leader>У :e!<CR>

" Save 
nnoremap <silent><leader>s :w<CR>
nnoremap <silent><leader>ы :w<CR>
nnoremap <silent><leader>S :w!<CR>
nnoremap <silent><leader>Ы :w!<CR>
command SaveSudo w !sudo tee %

" Close
nnoremap <silent><leader>q :call Close()<CR>
nnoremap <silent><leader>й :call Close()<CR>
nnoremap <silent><leader>Q :call Close_force()<CR>
nnoremap <silent><leader>Й :call Close_force()<CR>
nnoremap <silent><D-w> :call Close()<CR>
inoremap <silent><D-w> <C-o>:call Close()<CR>
function! Close()
    if len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
        quit
    else
        :bd
    endif
endfunction
function! Close_force()
    if len(filter(range(1, bufnr('$')), 'buflisted(v:val)')) == 1
        quit!
    else
        :bd!
    endif
endfunction

" Toggle LineNumbers
nnoremap <silent><leader>tr :set relativenumber!<CR>
nnoremap <silent><leader>ек :set relativenumber!<CR>

" Clear registers 
" let regs='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-"' | let i=0 | while (i<strlen(regs)) | exec 'let @'.regs[i].'=""' | let i=i+1 | endwhile | unlet regs

" Fix regs overwriting
" dd => cut
" leader d => delete
nnoremap x "_x
vnoremap x "_x
nnoremap D "_D
xnoremap p "_dP

nnoremap <leader>d ""d
nnoremap <leader>в ""d
vnoremap <leader>d ""d
vnoremap <leader>в ""d
nnoremap <leader>D ""D
nnoremap <leader>В ""D
" }}}

" {{{ Tabs with cmd +[0..9] 
noremap <D-1> 1gt
noremap <D-2> 2gt
noremap <D-3> 3gt
noremap <D-4> 4gt
noremap <D-5> 5gt
noremap <D-6> 6gt
noremap <D-7> 7gt
noremap <D-8> 8gt
noremap <D-9> 9gt
" }}} 

" {{{ Mac rebinds 
" not default keyboard.. Karabiner map alt-[b,f]
" fix meta-keys which generate <Esc>a .. <Esc>z
nmap œ <A-q>
nmap ∑ <A-w>
nmap ´ <A-e>
nmap ® <A-r>
nmap † <A-t>
nmap ¥ <A-y>
nmap ¨ <A-u>
nmap ˆ <A-i>
nmap ø <A-o>
nmap π <A-p>

nmap å <A-a>
nmap ß <A-s>
nmap ∂ <A-d>
" nmap <A-f> 
nmap © <A-g>
nmap ˙ <A-h>
nmap ∆ <A-j>
nmap ˚ <A-k>
nmap ¬ <A-l>

nmap Ω <A-z>
nmap ≈ <A-x>
nmap ç <A-c>
nmap √ <A-v>
" nmap <A-b>
nmap ˜ <A-n>
nmap µ <A-m>

vmap œ <A-q>
vmap ∑ <A-w>
vmap ´ <A-e>
vmap ® <A-r>
vmap † <A-t>
vmap ¥ <A-y>
vmap ¨ <A-u>
vmap ˆ <A-i>
vmap ø <A-o>
vmap π <A-p>

vmap å <A-a>
vmap ß <A-s>
vmap ∂ <A-d>
" vmap <A-f> 
vmap © <A-g>
vmap ˙ <A-h>
vmap ∆ <A-j>
vmap ˚ <A-k>
vmap ¬ <A-l>

vmap Ω <A-z>
vmap ≈ <A-x>
vmap ç <A-c>
vmap √ <A-v>
" vmap <A-b>
vmap ˜ <A-n>
vmap µ <A-m>

" Not working FIXME
imap œ <A-q>
imap ∑ <A-w>
imap ´ <A-e>
imap ® <A-r>
imap † <A-t>
imap ¥ <A-y>
imap ¨ <A-u>
imap ˆ <A-i>
imap ø <A-o>
imap π <A-p>

imap å <A-a>
imap ß <A-s>
imap ∂ <A-d>
" imap <A-f> 
imap © <A-g>
imap ˙ <A-h>
imap ∆ <A-j>
imap ˚ <A-k>
imap ¬ <A-l>

imap Ω <A-z>
imap ≈ <A-x>
imap ç <A-c>
imap √ <A-v>
" imap <A-b>
imap ˜ <A-n>
imap µ <A-m>
" }}} 

" {{{ Nerdcommenter
nmap <C-/> <leader>c<Space>
vmap <C-/> <leader>c<Space>
imap <C-/> <C-o><leader>c<Space>

" Stupid Mac term can't recognize <C>
nmap <C-_> <leader>c<Space>
vmap <C-_> <leader>c<Space>
imap <C-_> <C-o><leader>c<Space>

" }}}

" {{{ Git workflow
nmap [v <Plug>(GitGutterPrevHunk)
nmap хм <Plug>(GitGutterPrevHunk)
nmap ]v <Plug>(GitGutterNextHunk)
nmap ъм <Plug>(GitGutterNextHunk)
nmap <Leader>v <Plug>(GitGutterPreviewHunk)
nmap <Leader>м <Plug>(GitGutterPreviewHunk)
" }}}

" {{{ Folding
nnoremap <leader>z za
nnoremap <leader>я za
nnoremap <Tab> za<CR>k
nnoremap <S-Tab> zA<CR>k
nnoremap zz za
nnoremap яя za
nnoremap za zM
nnoremap яф zM
nnoremap zA zR
nnoremap яФ zR
" }}}

" {{{ Encoding menu
menu Encoding.koi8-r :e ++enc=koi8-r ++ff=unix<CR>
menu Encoding.windows-1251 :e ++enc=cp1251 ++ff=dos<CR>
menu Encoding.cp866 :e ++enc=cp866 ++ff=dos<CR>
menu Encoding.utf-8 :e ++enc=utf8<CR>
menu Encoding.koi8-u :e ++enc=koi8-u ++ff=unix<CR>

nmap <C-U> :emenu Encoding.
" }}}

" {{{ Grammar menu
" cd $(vim -e -T dumb --cmd 'exe "set t_cm=\<C-M>"|echo $VIMRUNTIME|quit' | tr -d '\015')
" cat <(ls -1 ftplugin/*.vim) <(ls -1 syntax/*.vim) | tr '\n' '\0' | xargs -0 -n 1 basename | sort | uniq | cut -f 1 -d '.'
menu Grammar.vim :set filetype=vim<CR>
menu Grammar.bash :set filetype=bash<CR>
menu Grammar.basic :set filetype=basic<CR>
menu Grammar.cfg :set filetype=cfg<CR>
menu Grammar.cf :set filetype=cf<CR>
menu Grammar.changelog :set filetype=changelog<CR>
menu Grammar.change :set filetype=change<CR>
menu Grammar.ch :set filetype=ch<CR>
menu Grammar.clean :set filetype=clean<CR>
menu Grammar.cmake :set filetype=cmake<CR>
menu Grammar.cmod :set filetype=cmod<CR>
menu Grammar.cmusrc :set filetype=cmusrc<CR>
menu Grammar.cobol :set filetype=cobol<CR>
menu Grammar.coco :set filetype=coco<CR>
menu Grammar.config :set filetype=config<CR>
menu Grammar.conf :set filetype=conf<CR>
menu Grammar.context :set filetype=context<CR>
menu Grammar.cpp :set filetype=cpp<CR>
menu Grammar.crontab :set filetype=crontab<CR>
menu Grammar.css :set filetype=css<CR>
menu Grammar.cs :set filetype=cs<CR>
menu Grammar.cterm :set filetype=cterm<CR>
menu Grammar.c :set filetype=c<CR>
menu Grammar.def :set filetype=def<CR>
menu Grammar.diff :set filetype=diff<CR>
menu Grammar.dns :set filetype=dns<CR>
menu Grammar.gdb :set filetype=gdb<CR>
menu Grammar.gitcommit :set filetype=gitcommit<CR>
menu Grammar.gitconfig :set filetype=gitconfig<CR>
menu Grammar.git :set filetype=git<CR>
menu Grammar.haskell :set filetype=haskell<CR>
menu Grammar.logcheck :set filetype=logcheck<CR>
menu Grammar.loginaccess :set filetype=loginaccess<CR>
menu Grammar.lua :set filetype=lua<CR>
menu Grammar.m4 :set filetype=m4<CR>
menu Grammar.make :set filetype=make<CR>
menu Grammar.manconf :set filetype=manconf<CR>
menu Grammar.manual :set filetype=manual<CR>
menu Grammar.man :set filetype=man<CR>
menu Grammar.markdown :set filetype=markdown<CR>
menu Grammar.messages :set filetype=messages<CR>
menu Grammar.mysql :set filetype=mysql<CR>
menu Grammar.objcpp :set filetype=objcpp<CR>
menu Grammar.objc :set filetype=objc<CR>
menu Grammar.obj :set filetype=obj<CR>
menu Grammar.ocaml :set filetype=ocaml<CR>
menu Grammar.pascal :set filetype=pascal<CR>
menu Grammar.passwd :set filetype=passwd<CR>
menu Grammar.pdf :set filetype=pdf<CR>
menu Grammar.php :set filetype=php<CR>
menu Grammar.phtml :set filetype=phtml<CR>
menu Grammar.psf :set filetype=psf<CR>
menu Grammar.python :set filetype=python<CR>
menu Grammar.raml :set filetype=raml<CR>
menu Grammar.rcs :set filetype=rcs<CR>
menu Grammar.rc :set filetype=rc<CR>
menu Grammar.readline :set filetype=readline<CR>
menu Grammar.registry :set filetype=registry<CR>
menu Grammar.resolv :set filetype=resolv<CR>
menu Grammar.scheme :set filetype=scheme<CR>
menu Grammar.sshconfig :set filetype=sshconfig<CR>
menu Grammar.sshdconfig :set filetype=sshdconfig<CR>
menu Grammar.stp :set filetype=stp<CR>
menu Grammar.sudoers :set filetype=sudoers<CR>
menu Grammar.syntax :set filetype=syntax<CR>
menu Grammar.sysctl :set filetype=sysctl<CR>
menu Grammar.systemd :set filetype=systemd<CR>
menu Grammar.tags :set filetype=tags<CR>
menu Grammar.text :set filetype=text<CR>
menu Grammar.tmux :set filetype=tmux<CR>
menu Grammar.wget :set filetype=wget<CR>
menu Grammar.whitespace :set filetype=whitespace<CR>
menu Grammar.xml :set filetype=xml<CR>
menu Grammar.xmodmap :set filetype=xmodmap<CR>
menu Grammar.xquery :set filetype=xquery<CR>
menu Grammar.yaml :set filetype=yaml<CR>
menu Grammar.zsh :set filetype=zsh<CR>

" nmap <C-O> :emenu Grammar.
" }}}

" {{{ FZF 
let $FZF_DEFAULT_COMMAND = 'ag -g ""'
nmap <A-z> <plug>(fzf-maps-n)
nmap <A-я> <plug>(fzf-maps-n)
xmap <A-z> <plug>(fzf-maps-x)
xmap <A-я> <plug>(fzf-maps-x)
omap <A-z> <plug>(fzf-maps-o)
omap <A-я> <plug>(fzf-maps-o)
autocmd FileType fzf tnoremap <buffer> <Esc> <c-g>

nnoremap <leader><space> :Commands<CR>
nnoremap <leader>p :Files<CR>
nnoremap <leader>з :Files<CR>
nnoremap <D-p> :Files<CR>
nnoremap <leader>I :Tags<CR>
nnoremap <leader>Ш :Tags<CR>
nnoremap <D-I> :Tags<CR>
nnoremap <leader>i :BTags<CR>
nnoremap <leader>ш :BTags<CR>
nnoremap <D-i> :BTags<CR>
nnoremap <leader>m :Marks<CR>
nnoremap <leader>ь :Marks<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>и :Buffers<CR>
nnoremap <leader>w :Windows<CR>
nnoremap <leader>ц :Windows<CR>
nnoremap <A-tab> :Buffers<CR>
nnoremap Q :History/<CR>
nnoremap Й :History/<CR>
nnoremap <leader>f :Ag<CR>
nnoremap <leader>а :Ag<CR>
nnoremap <D-f> :Ag<CR>
nnoremap <Leader>Fw :Ag<Space><C-r><C-w><CR>
nnoremap <Leader>Ац :Ag<Space><C-r><C-w><CR>
nnoremap <D-F> :Ag<Space><C-r><C-w><CR>

nnoremap <leader>Fc :AgC<CR>
nnoremap <leader>Ас :AgC<CR>
nnoremap <leader>Fh :AgH<CR>
nnoremap <leader>Ар :AgH<CR>
nnoremap <leader>FC :AgCC<CR>
nnoremap <leader>АС :AgCC<CR>
nnoremap <leader>Fp :AgPython<CR>
nnoremap <leader>Аз :AgPython<CR>
nnoremap <leader>Fr :AgRust<CR>
nnoremap <leader>Ак :AgRust<CR>
" }}} 

" {{{ Move lines
nnoremap <silent><C-j> :m .+1<CR>==
nnoremap <silent><C-k> :m .-2<CR>==
inoremap <silent><C-j> <Esc>:m .+1<CR>==gi
inoremap <silent><C-k> <Esc>:m .-2<CR>==gi
vnoremap <silent><C-j> :m '>+1<CR>gv=gv
vnoremap <silent><C-k> :m '<-2<CR>gv=gv
" }}}

" {{{ if Darwin
if uname == 'Darwin'
" {{{ Dash
nnoremap K :Dash<CR>
nnoremap Л :Dash<CR>
" }}}

endif
" }}}

" }}}

" {{{ Git workflow
let g:gitgutter_override_sign_column_highlight = 0
let g:gitgutter_map_keys = 0
" }}}

" {{{ Nerdcommenter settings
let g:NERDSpaceDelims = 1
let g:NERDRemoveExtraSpaces = 1
let g:NERDCompactSexyComs = 1
let g:NERDCommentEmptyLines = 1
let g:NERDAltDelims_c = 1

" }}}

" {{{ C/C++
au FileType c,h,cpp setlocal commentstring=//\ %s
au FileType c,h,cpp setlocal tw=80
" au FileType c,cpp call LCDisableAutostart(['linux-', 'Kernel', 'Projects', 'Bugs', 'beremiz'])

" Use C filetype for headers by default
au BufReadPre,BufRead,BufNewFile *.h set filetype=c


" clang include fixer
" let g:clang_include_fixer_path = "clang-include-fixer-7"
" au FileType c,cpp noremap <leader>Ei :pyf /usr/lib/llvm-7/share/clang/clang-include-fixer.py<cr>

" Apply Linux Kernel settings
" let g:linuxsty_patterns = [ "/usr/src/", "/linux" ]

" {{{ Commands and binds
" au FileType c call CmdC()
" function! CmdC()
    " " Clean debug prints from `prdbg` snippet
    " command! CleanDebugPrints :g/\/\/\ prdbg$/d
" endfunction
" }}}

" {{{ ctags
 " set autochdir
 set tags=tags
" set tags=./tags;
" let g:ctags_statusline=1
" let g:tagbar_type_rust = {
  " \ 'ctagstype' : 'rust',
  " \ 'kinds' : [
  " \'T:types,type definitions',
  " \'f:functions,function definitions',
  " \'g:enum,enumeration names',
  " \'s:structure names',
  " \'m:modules,module names',
  " \'c:consts,static constants',
  " \'t:traits',
  " \'i:impls,trait implementations',
  " \]
  " \}
" }}}
" }}}

" {{{ vimscript
let g:vim_indent_cont = 2
au FileType vim setlocal sw=4 ts=4 expandtab
au FileType vim setlocal foldmethod=marker foldlevel=0 foldenable
au FileType vim nnore <silent><buffer> K <Esc>:help <C-R><C-W><CR>
au FileType help noremap <buffer> q :q<cr>
" }}}

"{{{ The Silver Searcher
if executable('ag')
  " Use ag over grep
  set grepprg=ag\ --nogroup\ --nocolor

  " Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
  let g:ctrlp_user_command = 'ag %s -l --nocolor -g ""'

  " ag is fast enough that CtrlP doesn't need to cache
  let g:ctrlp_use_caching = 0
endif
"}}}

" {{{ Other files
autocmd FileType markdown set foldmethod=expr
au FileType markdown set fen tw=0 sw=2 foldlevel=0 foldexpr=NestedMarkdownFolds()
au FileType markdown let g:indentLine_conceallevel = 1
let g:vim_markdown_override_foldtext = 0
let g:vim_markdown_folding_style_pythonic = 1
let g:vim_markdown_folding_level = 0
let g:vim_markdown_initial_foldlevel=0
let g:vim_markdown_folding_disabled=1
au FileType conf set foldmethod=marker foldenable
au FileType sh set foldmethod=marker foldenable
au FileType zsh setlocal foldmethod=marker foldlevel=0 foldenable
au Filetype css setlocal ts=4
au Filetype html setlocal ts=4
au BufReadPre,BufRead,BufNewFile *.fish set filetype=sh
au BufReadPre,BufRead,BufNewFile *.bashrc set filetype=sh
au BufReadPre,BufRead,BufNewFile *.conf set filetype=conf
au BufReadPre,BufRead,BufNewFile *.cnf set filetype=conf
au BufReadPre,BufRead,BufNewFile monitrc set filetype=conf

" buildbot configuration files
au BufNewFile,BufRead   master.cfg      set ft=python foldmethod=marker foldenable tw=120
au BufNewFile,BufRead   buildbot.tac    set ft=python foldmethod=marker foldenable tw=120

au BufNewFile,BufRead   .pdbrc set ft=python

" Taskwarrior tasks (`task [id] edit`)
au BufRead *.task /Description:

" Always start on first line of git commit message
au FileType gitcommit call setpos('.', [0, 1, 1, 0])

au BufNewFile,BufRead .clang-format set ft=config
" }}}

" {{{ FZF
set rtp+=/usr/local/opt/fzf
let g:fzf_history_dir = '~/.local/share/fzf-history'

" Pass raw arguments directly to ag command
command! -bang -nargs=+ -complete=dir Rag call fzf#vim#ag_raw(<q-args>, {'options': '--delimiter : --nth 4..'}, <bang>0)

" Recently used files
command! FZFMru call fzf#run({
\  'source':  v:oldfiles,
\  'sink':    'e',
\  'options': '-m -x +s',
\  'down':    '40%'})

function! s:all_files()
return extend(
\ filter(copy(v:oldfiles),
\        "v:val !~ 'fugitive:\\|NERD_tree\\|^/tmp/\\|.git/'"),
\ map(filter(range(1, bufnr('$')), 'buflisted(v:val)'), 'bufname(v:val)'))
endfunction

" Augmenting Ag command using fzf#vim#with_preview function
" :Ag  - Start fzf with hidden preview window that can be enabled with "?" key
" :Ag! - Start fzf in fullscreen and display the preview window above
command! -bang -nargs=* Ag
\ call fzf#vim#ag(<q-args>, '--path-to-ignore ~/.ignore',
\                 <bang>0 ? fzf#vim#with_preview('up:60%')
\                         : fzf#vim#with_preview('right:50%', '?'),
\                 <bang>0)

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

" Search in specific file types
command! -bang -nargs=* AgC call fzf#vim#ag(<q-args>, '-G \.c$', {'down': '~40%'})
command! -bang -nargs=* AgH call fzf#vim#ag(<q-args>, '-G \.h$', {'down': '~40%'})
command! -bang -nargs=* AgCC call fzf#vim#ag(<q-args>, '--cc', {'down': '~40%'})
command! -bang -nargs=* AgPython call fzf#vim#ag(<q-args>, '--python', {'down': '~40%'})
command! -bang -nargs=* AgRust call fzf#vim#ag(<q-args>, '--rust', {'down': '~40%'})

let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }
" }}}

" {{{ Bookmarks

let g:bookmark_save_per_working_dir = 1
let g:bookmark_auto_save = 1

call unite#custom#profile('source/vim_bookmarks', 'context', {
	\   'winheight': 13,
	\   'direction': 'botright',
	\   'start_insert': 0,
	\   'keep_focus': 1,
	\   'no_quit': 0,
	\ })
" }}} 
