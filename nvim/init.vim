set nocompatible
let mapleader = "\<Space>"
if &shell =~# 'fish$'
  set shell=/bin/bash
endif

" {{{ Plugins
call plug#begin('~/.nvim/plugged')

" {{{ UI & appearance
Plug 'https://github.com/itchyny/lightline.vim'
Plug 'https://github.com/Shougo/unite.vim'
Plug 'https://github.com/arcticicestudio/nord-vim'
Plug 'https://github.com/chrisbra/Colorizer'       " Colorize color names and codes
Plug 'https://github.com/junegunn/vim-peekaboo'    " Shows vim registers content into vertical split
Plug 'https://github.com/Yggdroot/indentLine'      " Show indentation as vertical lines
Plug 'https://github.com/haya14busa/incsearch.vim' " Incrementally highlight search results
Plug 'https://github.com/liuchengxu/vim-which-key' " Display available keybindings in popup
Plug 'https://github.com/jubnzv/vim-cursorword'    " Highlight word under cursor
Plug 'https://github.com/godlygeek/tabular'         " Vim script for text filtering and alignment
Plug 'https://github.com/tpope/vim-surround'
Plug 'MattesGroeger/vim-bookmarks'
Plug 'https://github.com/jiangmiao/auto-pairs'      " Insert or delete brackets, parens, quotes in pair
" }}}

" {{{ Git
Plug 'https://github.com/airblade/vim-gitgutter' 
" }}}

" {{{ Writing code
Plug 'https://github.com/majutsushi/tagbar'            " Vim plugin that displays tags in a window
Plug 'https://github.com/ludovicchabant/vim-gutentags' " Auto (re)generate tag files
Plug 'https://github.com/terryma/vim-expand-region'    " Visually select increasingly larger regions of text
Plug 'https://github.com/Shougo/echodoc.vim'           " Displays function signatures from completions in the command line
Plug 'https://github.com/scrooloose/nerdcommenter'
Plug 'https://github.com/Shougo/neosnippet.vim'
Plug 'https://github.com/Shougo/neosnippet-snippets'
Plug 'https://github.com/Shougo/neoinclude.vim'
Plug 'https://github.com/Shougo/deoplete.nvim', { 'do': ':UpdateRemotePlugins' }
Plug 'autozimu/LanguageClient-neovim', { 'tag': 'release-1.2.3-bin-darwin' }
Plug 'https://github.com/ervandew/supertab'
Plug 'https://github.com/jubnzv/DoxygenToolkit.vim'
" Plug 'https://github.com/vivien/vim-linux-coding-style'
Plug 'https://github.com/nacitar/a.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'https://github.com/justinmk/vim-syntax-extra'
" Plug 'arakashic/chromatica.nvim'
" Plug 'https://github.com/w0rp/ale'
" Plug 'https://github.com/simplyzhao/cscope_maps.vim'
" Plug 'prabirshrestha/async.vim'
" Plug 'prabirshrestha/vim-lsp'
" Plug 'https://github.com/justmao945/vim-clang'
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
set undodir=$HOME/.vim/undo
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
set notimeout                               " Remove delay between complex keybindings.
set ttimeoutlen=0
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

let &t_SI.="\e[5 q" "SI = INSERT mode
let &t_SR.="\e[4 q" "SR = REPLACE mode
let &t_EI.="\e[2 q" "EI = NORMAL mode (ELSE)

" Italic symbols in terminal
set t_ZH=^[[3m
set t_ZR=^[[23m

colorscheme nord

" Highlighting
hi CursorLine ctermbg=236
hi CursorLineNr ctermbg=236
hi ColorColumn ctermbg=236
hi Todo ctermfg=130 guibg=#af3a03

" let g:indentLine_concealcursor = 'inc'
let g:indentLine_conceallevel = 10

let g:indentLine_char = '⎸'


let g:indentLine_enabled = 1
set listchars=tab:\⎸\ 

set list
" }}}

" {{{ Lightline
let g:lightline = {
  \ 'colorscheme': 'nord',
  \ 'active': {
  \   'left':  [ [ 'mode', 'paste' ],
  \              [ 'filename', 'modified' ],
  \              [ 'tagbar' ] ],
  \   'right': [ [ 'lineinfo' ],
  \              [ 'percent' ],
  \              [ 'lsp_status' ],
  \              [ 'fileformat', 'fileencoding', 'filetype' ],
  \              [ 'gitbranch' ] ],
  \ },
  \ 'component_function': {
  \   'gitbranch': 'fugitive#head'
  \ },
  \ 'component': {
  \   'lineinfo': "%c:%{line('.') . '/' . line('$')}",
  \   'modified': '%{&filetype=="help"?"":&modified?"":&modifiable?"":"\u2757"}',
  \   'fugitive': '%{exists("*fugitive#head")?fugitive#head():""}',
  \   'tagbar': '%{tagbar#currenttag("[%s]", "", "f")}',
  \ },
  \ 'component_expand': {
  \   'lsp_status': 'LightlineLSPStatus'
  \ },
  \ 'component_type': {
  \   'lsp_warnings': 'warning',
  \   'lsp_errors': 'error',
  \   'readonly': 'error'
  \ },
  \ }
" }}}

" {{{Chromatica
" let g:chromatica#enable_at_startup=1
" let g:chromatica#libclang_path='/usr/local/opt/llvm/lib'
" let g:chromatica#responsive_mode=1
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

" {{{ Customized `CustomFoldText` function:
" http://www.gregsexton.org/2011/03/improving-the-text-displayed-in-a-fold/
function! CustomFoldText()
  let fs = v:foldstart
  while getline(fs) =~ '^\s*$' | let fs = nextnonblank(fs + 1)
  endwhile
  if fs > v:foldend
    let line = getline(v:foldstart)
  else
    let line = substitute(getline(fs), '\t', repeat(' ', &tabstop), 'g')
  endif

  let w = &l:textwidth - 3 - &foldcolumn - (&number ? 8 : 0)
  let foldSize = 1 + v:foldend - v:foldstart
  " let foldLevelStr = "" . string(v:foldlevel)
  let foldLevelStr = ""
  let lineCount = line("$")
  let foldSizeStr = printf("[%4dL|%4.1f%%]", foldSize, (foldSize*1.0)/lineCount*100)
  let expansionString = " " . repeat(" ", w - strwidth(foldSizeStr.line.foldLevelStr))
  return  line . expansionString . foldLevelStr . " " . foldSizeStr
endf
set foldtext=CustomFoldText()
" }}}

" {{{ VimFold4C
" let g:fold_options = {
   " \ 'fallback_method' : { 'line_threshold' : 2000, 'method' : 'syntax' },
   " \ 'fold_blank': 0,
   " \ 'fold_includes': 0,
   " \ 'max_foldline_length': 'win',
   " \ 'merge_comments' : 0,
   " \ 'show_if_and_else': 1,
   " \ 'strip_namespaces': 1,
   " \ 'strip_template_arguments': 1
   " \ }
" }}}
" }}}

" {{{ Keybindings <A-...> <D-...>

" Need to find out if gui running and map <D> to <M>

" {{{ Common
" Binds that changes default vim behavior, separated from plugins
" configuration.
"
inoremap jj <Esc>
nnoremap <leader>h :noh<CR>
map <Leader><ESC> :pclose<CR>:noh<CR>:echo<CR>
nnoremap <ENTER> :pclose<CR>:noh<CR>:echo<CR>

" Insert newline without entering insert mode
nmap zj o<Esc>k
nmap zk O<Esc>j

" Reload vimrc
nnoremap <leader>R :so $MYVIMRC<CR>:echo "Config reloaded"<CR>

" Clear ':'
nmap <F1> :echo <CR>
imap <F1> <C-o>:echo <CR>
nmap <A-k> :noh<CR>:echo<CR>

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

" Delete word in insert
inoremap <M-BS> <C-o>b<C-o>de

" Tab Restore
nnoremap <S-D-t> :call ReopenLastTab()<CR>:echo<CR>

" Save 
nnoremap <leader>s :w<CR>

" Close
nnoremap <leader>q :bd<CR>

" d => cut
" leader d => delete
" nnoremap p "_dP
" xnoremap p "_dP
" nnoremap <leader>d "_d
" vnoremap <leader>d "_d
" nnoremap <leader>D "_D
" nnoremap <leader>x "_x
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

" {{{ Tagbar
" nnoremap <A-\> :TagbarOpenAutoClose<CR>
nnoremap <D-\> :TagbarOpenAutoClose<CR>
" inoremap <A-\> <C-o>:TagbarOpenAutoClose<CR>
inoremap <D-\> <C-o>:TagbarOpenAutoClose<CR>
" }}}

" {{{ Git workflow
nmap [v <Plug>GitGutterPrevHunk
nmap ]v <Plug>GitGutterNextHunk
nmap <Leader>v <Plug>GitGutterPreviewHunk
" }}}

" {{{ Folding
nnoremap <leader>z za
nnoremap zz za
nnoremap za zM
nnoremap zA zR
" }}}

" {{{ Encoding menu
menu Encoding.koi8-r :e ++enc=koi8-r ++ff=unix<CR>
menu Encoding.windows-1251 :e ++enc=cp1251 ++ff=dos<CR>
menu Encoding.cp866 :e ++enc=cp866 ++ff=dos<CR>
menu Encoding.utf-8 :e ++enc=utf8<CR>
menu Encoding.koi8-u :e ++enc=koi8-u ++ff=unix<CR>

map <C-U> :emenu Encoding.
" }}}

" {{{ FZF 
let $FZF_DEFAULT_COMMAND = 'ag -g ""'
nmap <A-z> <plug>(fzf-maps-n)
xmap <A-z> <plug>(fzf-maps-x)
omap <A-z> <plug>(fzf-maps-o)
autocmd FileType fzf tnoremap <buffer> <Esc> <c-g>

nnoremap <leader><space> :Commands<CR>
nnoremap <leader>xf :Files<CR>
nnoremap <D-p> :Files<CR>
nnoremap <leader>ft :Tags<CR>
nnoremap <S-D-i> :Tags<CR>
nnoremap <D-i> :BTags<CR>
nnoremap <leader>fm :Marks<CR>
nnoremap <leader>b :Buffers<CR>
nnoremap <leader>w :Windows<CR>
nnoremap <A-tab> :Buffers<CR>
nnoremap <leader>xr :FZFMru <CR>
nnoremap Q :History/<CR>
nnoremap <leader>fs :Ag<CR>
nnoremap <D-f> :Ag<CR>
nnoremap <Leader>fw :Ag<Space><C-r><C-w><CR>
nnoremap <S-D-f> :Ag<Space><C-r><C-w><CR>

nnoremap <leader>fc :AgC<CR>
nnoremap <leader>fh :AgH<CR>
nnoremap <leader>fC :AgCC<CR>
nnoremap <leader>fp :AgPython<CR>
nnoremap <leader>fr :AgRust<CR>
" }}} 

" {{{ GUI
map <M-s> <ESC>:w<CR>
" nnoremap <M-w> :q<CR>
" inoremap <M-w> <ESC><C-o>:q<CR>
nnoremap <D-w> :q<CR>
inoremap <D-w> <ESC><C-o>:q<CR>
map <D-n> :tabnew<CR>
" }}}

" {{{ C/C++
" open tag in new tab
nnoremap <silent><C-S-]> <C-w><C-]><C-w>T
nnoremap <M-]> <C-]>
" Switch between header and sources
nmap <A-a> :A<CR>
" }}}

" {{{ neosnippet
imap <A-l> <Plug>(neosnippet_expand_or_jump)
smap <A-l> <Plug>(neosnippet_expand_or_jump)
smap <A-l> <Plug>(neosnippet_expand_or_jump)
xmap <A-l> <Plug>(neosnippet_expand_target)
imap <C-l> <Plug>(neosnippet_expand_or_jump)
smap <C-l> <Plug>(neosnippet_expand_or_jump)
xmap <C-l> <Plug>(neosnippet_expand_target)
inoremap <silent> <Esc> <esc>:NeoSnippetClearMarkers<cr>
snoremap <silent> <Esc> <esc>:NeoSnippetClearMarkers<cr>


" smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
" \ "\<Plug>(neosnippet_expand_or_jump)" : "\<TAB>"

" imap <expr><TAB> neosnippet#jumpable() ?
imap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: pumvisible() ? "\<C-w>" : "\<TAB>"
" \: pumvisible() ? "\<ENTER>" : "\<TAB>"
 
" smap <expr><TAB> neosnippet#jumpable() ?
smap <expr><TAB> neosnippet#expandable_or_jumpable() ?
\ "\<Plug>(neosnippet_expand_or_jump)"
\: "\<TAB>"

" For snippet_complete marker.
if has('conceal')
  set conceallevel=2 concealcursor=niv
endif
" }}}

" {{{ Clang
" rebind LSP keys
" nmap <C-'> :cscope<CR>
" nmap <A-'> :cscope<CR>
nmap <D-'> :cscope<CR>
    " nmap gm :cscope<CR>
    " nmap gM :cscope<CR>
    " nmap gs :scs find s <C-R>=expand("<cword>")<CR><CR>	
    " nmap gd :scs find g <C-R>=expand("<cword>")<CR><CR>	
    " nmap gc :scs find c <C-R>=expand("<cword>")<CR><CR>	
    " nmap gt :scs find t <C-R>=expand("<cword>")<CR><CR>	
    " nmap ge :scs find e <C-R>=expand("<cword>")<CR><CR>	
    " nmap gf :scs find f <C-R>=expand("<cfile>")<CR><CR>	
    " nmap gi :scs find i ^<C-R>=expand("<cfile>")<CR>$<CR>	
    " nmap gr :scs find d <C-R>=expand("<cword>")<CR><CR>

" }}}

" {{{ LSP 
nnoremap <leader>tl :call ToggleLSP()<CR>
" I keep it as separated function to use this hotkeys when LSP is not started, e.g. use ctags/cscope binds for goto
" definition / goto implementation in large C projects when LSP is slow.
function! LCKeymap()
  if has_key(g:LanguageClient_serverCommands, &filetype)
    nnoremap <silent> gd :call LanguageClient#textDocument_definition()<cr>
    nnoremap gD :only<bar>vsplit<cr>gd
    nnoremap <silent> gi :call LanguageClient#textDocument_implementation()<cr>
    nnoremap <silent> gK :call LanguageClient#textDocument_hover()<cr>
    nnoremap <silent> gm :call LanguageClient_contextMenu()<CR>
    nnoremap <silent> gr :call LanguageClient_textDocument_references()<cr>
    nnoremap <silent> gs :call LanguageClient#workspace_symbol()<cr>
    nnoremap <silent> <F6> :call LanguageClient#textDocument_rename()<cr>
  endif
endfunction
" }}}

" {{{ Move lines
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==
inoremap <C-j> <Esc>:m .+1<CR>==gi
inoremap <C-k> <Esc>:m .-2<CR>==gi
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv
" }}}

" {{{ Deoplete
" deoplete tab-complete
function! TabWrap()
    if pumvisible()
        return "\<C-N>"
    elseif strpart( getline('.'), 0, col('.') - 1 ) =~ '^\s*$'
        return "\<tab>"
    elseif &omnifunc !~ ''
        return "\<C-X>\<C-O>"
    else
        return "\<C-N>"
    endif
endfunction

" "use <tab> for completion
" imap <silent><expr><tab> TabWrap()
" inoremap <expr><tab> pumvisible()? "\<ENTER>" : "\<tab>"

" Enter: complete&close popup if visible (so next Enter works); else: break undo
inoremap <silent><expr> <Cr> pumvisible() ?
            \ deoplete#mappings#close_popup() : "<C-g>u<Cr>"

" Ctrl-Space: summon FULL (synced) auocompletion
inoremap <silent><expr> <C-Space> deoplete#mappings#manual_complete()

"Escape: exit autocompletion, go to Normal mode
" inoremap <silent><expr> <Esc> pumvisible() ? "<C-o><Esc>" : "<Esc>"
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

" {{{ Reopen last buffer
let g:reopenbuf = expand('%:p')
function! ReopenLastTabLeave()
  let g:lastbuf = expand('%:p')
  let g:lasttabcount = tabpagenr('$')
endfunction
function! ReopenLastTabEnter()
  if tabpagenr('$') < g:lasttabcount
    let g:reopenbuf = g:lastbuf
  endif
endfunction
function! ReopenLastTab()
  tabnew
  execute 'buffer' . g:reopenbuf
endfunction
augroup ReopenLastTab
  autocmd!
  autocmd TabLeave * call ReopenLastTabLeave()
  autocmd TabEnter * call ReopenLastTabEnter()
augroup END
"}}} 

" {{{ NerdTree
" autocmd vimenter * NERDTree

let g:NERDTreeFileExtensionHighlightFullName = 1
let g:NERDTreeExactMatchHighlightFullName = 1
let g:NERDTreePatternMatchHighlightFullName = 1
" set encoding=utf8
" let g:NERDTreeShowIgnoredStatus = 1
let NERDTreeRespectWildIgnore=1
" set guifont=font-hack-nerd-font
" NERDTress File highlighting
function! NERDTreeHighlightFile(extension, fg, bg, guifg, guibg)
 exec 'autocmd filetype nerdtree highlight ' . a:extension .' ctermbg='. a:bg .' ctermfg='. a:fg .' guibg='. a:guibg .' guifg='. a:guifg
 exec 'autocmd filetype nerdtree syn match ' . a:extension .' #^\s\+.*'. a:extension .'$#'
endfunction

call NERDTreeHighlightFile('jade', 'green', 'none', 'green', '#151515')
" call NERDTreeHighlightFile('c', 'green', 'none', 'green', '#151515')
call NERDTreeHighlightFile('ini', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('md', 'blue', 'none', '#3366FF', '#151515')
call NERDTreeHighlightFile('yml', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('config', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('conf', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('json', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('html', 'yellow', 'none', 'yellow', '#151515')
call NERDTreeHighlightFile('styl', 'cyan', 'none', 'cyan', '#151515')
call NERDTreeHighlightFile('css', 'cyan', 'none', 'cyan', '#151515')
call NERDTreeHighlightFile('coffee', 'Red', 'none', 'red', '#151515')
call NERDTreeHighlightFile('js', 'Red', 'none', '#ffa500', '#151515')
call NERDTreeHighlightFile('php', 'Magenta', 'none', '#ff00ff', '#151515')
" 
" }}} 

" {{{ C/C++
au FileType c,h,cpp setlocal commentstring=//\ %s
au FileType c,h,cpp setlocal tw=80
" au FileType c,cpp call LCDisableAutostart(['linux-', 'Kernel', 'Projects', 'Bugs', 'beremiz'])
au FileType c,h,cpp call LCKeymap()
" au FileType c,cpp call LoadCscope()

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

" {{{ CScope
" function! LoadCscope()
  " let db = findfile("cscope.out", ".;")
  " if (!empty(db))
    " let path = strpart(db, 0, match(db, "/cscope.out$"))
    " set nocscopeverbose " suppress 'duplicate connection' error
    " exe "cs add " . db . " " . path
    " set cscopeverbose
  " " else add the database pointed to by environment variable 
  " elseif $CSCOPE_DB != "" 
    " cs add $CSCOPE_DB
  " endif
" endfunction
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
au FileType conf set foldmethod=marker foldenable
au Filetype css setlocal ts=4
au Filetype html setlocal ts=4
au BufReadPre,BufRead,BufNewFile *.fish set filetype=sh
au BufReadPre,BufRead,BufNewFile *.bashrc set filetype=sh

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

" {{{ 80+ characters line highlight
function! s:SetColorColumn()
  if &textwidth == 0
    setlocal colorcolumn=80
  else
    setlocal colorcolumn=+0
  endif
endfunction

augroup colorcolumn
  au!
  au OptionSet textwidth call s:SetColorColumn()
  au BufEnter * call s:SetColorColumn()
augroup end
" }}}

" {{{ deoplete
let g:deoplete#enable_at_startup = 1 
let g:deoplete#enable_smart_case = 1
let g:deoplete#sources#syntax#min_keyword_length = 1
let g:deoplete#ignore_sources = {}
call deoplete#custom#option('min_pattern_length', 1)
call deoplete#custom#var('around', {
\   'range_above': 100,
\   'range_below': 100,
\   'mark_above': '[↑]',
\   'mark_below': '[↓]',
\   'mark_changes': '[]',
\})
let g:deoplete#ignore_sources._ = ['buffer']
let g:deoplete#ignore_sources.c = ['buffer', 'around']
call deoplete#custom#source('_',
 \ 'matchers', ['matcher_full_fuzzy'])

call deoplete#custom#source('LanguageClient',
  \ 'min_pattern_length',
  \ 2)
" 
set completeopt+=menu,noinsert
" set completeopt+=noinsert
" set completeopt+=preview
" }}}

" {{{ neosnippet
let g:neosnippet#disable_runtime_snippets = {
        \   '_' : 1,
        \ }
let g:neosnippet#enable_completed_snippet = 1
let g:neosnippet#enable_auto_clear_markers = 1
let g:neosnippet#enable_complete_done = 1
let g:neosnippet#enable_conceal_marker = 1

" If your snippets trigger are same with builtin snippets, your snippets overwrite them.
let g:neosnippet#snippets_directory='~/.config/nvim/snippets'
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

" {{{ FZF
set rtp+=/usr/local/opt/fzf
let g:fzf_history_dir = '~/.local/share/fzf-history'
" let g:fzf_tags_command = 'ctags -R *.c'
let g:fzf_tags_command = 'ctags -R --languages=c,c++'


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
command! -bang -nargs=* AgC
\ call fzf#vim#ag(<q-args>, '--path-to-ignore ~/.ignore -G \.c$',
\                 <bang>0 ? fzf#vim#with_preview('up:60%')
\                         : fzf#vim#with_preview('right:50%', '?'),
\                 <bang>0)
command! -bang -nargs=* AgH
\ call fzf#vim#ag(<q-args>, '--path-to-ignore ~/.ignore -G \.h$',
\                 <bang>0 ? fzf#vim#with_preview('up:60%')
\                         : fzf#vim#with_preview('right:50%', '?'),
\                 <bang>0)
command! -bang -nargs=* AgCC call fzf#vim#ag(<q-args>, '--cc', {'down': '~40%'})
command! -bang -nargs=* AgPython call fzf#vim#ag(<q-args>, '--python', {'down': '~40%'})
command! -bang -nargs=* AgRust call fzf#vim#ag(<q-args>, '--rust', {'down': '~40%'})
" }}}

" {{{ LanguageClient settings
" let g:LanguageClient_loggingFile = '/tmp/LanguageClient.log'
let g:LanguageClient_loadSettings = 1
let g:LanguageClient_autoStart = 0
let g:LanguageClient_hasSnippetSupport = 1
let g:lsp_diagnostics_enabled = 1
let g:lsp_diagnostics_echo_cursor = 1
let g:LanguageClient_waitOutputTimeout = 5
" let g:LanguageClient_hoverPreview = "Never"
let g:LanguageClient_settingsPath = '~/.config/nvim/settings.json'
let g:LanguageClient_serverCommands = {
  \ 'cpp': ['/usr/local/Cellar/llvm/7.0.1/bin/clangd'],
  \ 'c': ['/usr/local/Cellar/llvm/7.0.1/bin/clangd'],
  \ }
" let g:LanguageClient_serverCommands = {
  " \ 'cpp': ['/usr/local/Cellar/llvm/7.0.1/bin/clang-query'],
  " \ 'c': ['/usr/local/Cellar/llvm/7.0.1/bin/clang-query'],
  " \ }
" let g:LanguageClient_serverCommands = {
  " \ 'cpp': ['/usr/local/bin/cquery', '--log-file=/tmp/cquery.log'],
  " \ 'c': ['/usr/local/bin/cquery', '--log-file=/tmp/cquery.log'],
  " \ }
" let g:LanguageClient_serverCommands = {
  " \ 'cpp': ['/usr/local/bin/cquery'],
  " \ 'c': ['/usr/local/bin/cquery'],
  " \ }
" let g:LanguageClient_serverCommands = {
  " \ 'cpp': ['clangd', '--log-file=/tmp/clang.log', '--I/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include'],
  " \ 'c': ['clangd', '--log-file=/tmp/clang.log', '--I/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include'],
  " \ }
" let g:LanguageClient_rootMarkers = {
  " \ 'cpp': ['compile_commands.json', 'build'],
  " \ 'c': ['compile_commands.json', 'build'],
  " \ }

" FIXME: Can be broken with cquery on some projects: use default `gq` instead.
" set formatexpr=LanguageClient_textDocument_rangeFormatting()
" set formatexpr=""

" Suppress autostart for large codebases
function! LCDisableAutostart(ignored_paths)
  let l:path = expand('%:p')
  for ign_path in a:ignored_paths
    if l:path =~ ign_path
      let g:LanguageClient_autoStart = 0
      break
    endif
  endfor
endfunction

function! ToggleLSP()
  if (g:lsp_status == 0)
    execute ":LanguageClientStart"
    let g:LanguageClient_autoStart = 1
    echo 'Enable LSP'
  else
    execute ":LanguageClientStop"
    let g:LanguageClient_autoStart = 0
    echo 'Disable LSP'
  endif
endfunction

" {{{ Format options for LSP diagnostic messages in signcolumn
let g:LanguageClient_diagnosticsEnable = 1

" Use something different for highlighting
" let sign_column_color=synIDattr(hlID('SignColumn'), 'bg#')
" execute "hi LSPError gui=undercurl cterm=underline term=underline guisp=red"
" execute "hi LSPErrorText guifg=yellow ctermbg=red  ctermfg=" . sign_column_color . "guibg=" . sign_column_color
" execute "hi LSPWarning gui=undercurl cterm=underline term=underline guisp=yellow"
" execute "hi LSPWarningText guifg=yellow ctermfg=yellow ctermbg=" . sign_column_color . "guibg=" . sign_column_color
" execute "hi LSPInfo gui=undercurl cterm=underline term=underline guisp=yellow"
" execute "hi LSPInfoText guifg=yellow ctermfg=yellow ctermbg=" . sign_column_color . "guibg=" . sign_column_color

" let g:LanguageClient_diagnosticsDisplay = {
  " \   1: {
  " \       "name": "Error",
  " \       "texthl": "LSPError",
  " \       "signText": "ee",
  " \       "signTexthl": "LSPErrorText",
  " \   },
  " \   2: {
  " \       "name": "Warning",
  " \       "texthl": "LSPWarning",
  " \       "signText": "ww",
  " \       "signTexthl": "LSPWarningText",
  " \   },
  " \   3: {
  " \       "name": "Information",
  " \       "texthl": "LSPInfo",
  " \       "signText": "ii",
  " \       "signTexthl": "LSPInfoText",
  " \   },
  " \   4: {
  " \       "name": "Hint",
  " \       "texthl": "LSPInfo",
  " \       "signText": "hh",
  " \       "signTexthl": "LSPInfoText",
  " \   },}
" }}}

" {{{ Functions to show LanguageClient status in modeline
augroup LanguageClient_config
  au!
  au User LanguageClientStarted call LSPUpdateStatus(1)
  au User LanguageClientStopped call LSPUpdateStatus(0)
augroup END
let g:lsp_status = 0
function! LSPUpdateStatus(status) abort
  let g:lsp_status = a:status
  call lightline#update()
endfunction
function! LightlineLSPStatus() abort
  return g:lsp_status == 1 ? 'Λ' : ''
endfunction
" }}}

" }}}

