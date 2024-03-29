set nocompatible
if &shell =~# 'fish$'
  set shell=/bin/bash
endif

" {{{ General
filetype on
autocmd FileType c setlocal foldmethod=syntax
" setlocal foldmethod=syntax
set viminfo='1000,f1                        " Save global marks for up to 1000 files
set scrolloff=7                             " 7 lines above/below cursor when scrolling
set scroll=7                                " Number of lines scrolled by <C-u> and <C-d>
set undofile
set undodir=~/.vim/undo

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

" Highlighting
hi CursorLine ctermbg=236
hi CursorLineNr ctermbg=236
hi ColorColumn ctermbg=236
hi Todo ctermfg=130 guibg=#af3a03

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
map <Space><ESC> :pclose<CR>:noh<CR>:echo<CR>
nnoremap <ENTER> :pclose<CR>:noh<CR>:echo<CR>

" Insert newline without entering insert mode
nnoremap zj o<Esc>k
nnoremap zk O<Esc>j
nnoremap яо o<Esc>k
nnoremap ял O<Esc>j

" find word under cursor
nnoremap # *
nnoremap * #

" Reload vimrc
nnoremap <Space>R :so $MYVIMRC<CR>:echo "Config reloaded"<CR>
nnoremap <Space>К :so $MYVIMRC<CR>:echo "Config reloaded"<CR>

" Open config files
nnoremap <Space>C :cd ~/.config<CR>:next .bashrc fish/config.fish .vimrc nvim/init.vim karabiner/karabiner.json install.sh .tmux.conf<CR>
nnoremap <Space>С :cd ~/.config<CR>:next .bashrc fish/config.fish .vimrc nvim/init.vim karabiner/karabiner.json install.sh .tmux.conf<CR>

" Open bookmarks
nnoremap <Space>B :cd ~/OneDrive/Notes<CR>:FZF<CR>
nnoremap <Space>И :cd ~/OneDrive/Notes<CR>:FZF<CR>

" Insert current time
nnoremap <Space>td "=strftime("%x %X")<CR>P
nnoremap <Space>ев "=strftime("%x %X")<CR>P

" Create new split
nnoremap <Space><leader>k :vsplit_v<CR>
nnoremap <Space><leader>л :vsplit_v<CR>

" Search highlighted text
vnoremap // y/<C-R>"<CR>

" Reload buffer
nnoremap <silent><Space>e :e<CR>
nnoremap <silent><Space>у :e<CR>
nnoremap <silent><Space>E :e!<CR>
nnoremap <silent><Space>У :e!<CR>

" Save 
nnoremap <silent><Space>s :w<CR>
nnoremap <silent><Space>ы :w<CR>
nnoremap <silent><Space>S :w!<CR>
nnoremap <silent><Space>Ы :w!<CR>
command SaveSudo w !sudo tee %

" Close
nnoremap <silent><Space>q :q<CR>
nnoremap <silent><Space>й :q<CR>
nnoremap <silent><Space>Q :q!<CR>
nnoremap <silent><Space>Й :q!<CR>

" Toggle LineNumbers
nnoremap <silent><Space>tr :set relativenumber!<CR>
nnoremap <silent><Space>ек :set relativenumber!<CR>

" Clear registers 
" let regs='abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/-"' | let i=0 | while (i<strlen(regs)) | exec 'let @'.regs[i].'=""' | let i=i+1 | endwhile | unlet regs

" Fix regs overwriting
" dd => cut
" Space d => delete
nnoremap x "_x
vnoremap x "_x
nnoremap D "_D
xnoremap p "_dP

nnoremap <Space>d ""d
nnoremap <Space>в ""d
vnoremap <Space>d ""d
vnoremap <Space>в ""d
nnoremap <Space>D ""D
nnoremap <Space>В ""D
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

" {{{ Folding
nnoremap <Space>z za
nnoremap <Space>я za
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

nmap <Space>U :emenu Encoding.
" }}}

" {{{ Move lines
nnoremap <silent><C-j> :m .+1<CR>==
nnoremap <silent><C-k> :m .-2<CR>==
inoremap <silent><C-j> <Esc>:m .+1<CR>==gi
inoremap <silent><C-k> <Esc>:m .-2<CR>==gi
vnoremap <silent><C-j> :m '>+1<CR>gv=gv
vnoremap <silent><C-k> :m '<-2<CR>gv=gv
" }}}

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

