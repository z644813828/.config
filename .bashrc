
# export PATH="/usr/local/opt/llvm/bin:$PATH"
# export PATH="/usr/local/opt/bison/bin:$PATH"
# export PATH="/usr/local/opt/bison/bin:$PATH"
# export PATH="$PATH:/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include"
# export LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include"
# export LD_LIBRARY_PATH="/Library/Developer/CommandLineTools/SDKs/MacOSX10.14.sdk/usr/include"


alias r='ranger'
set -x EDITOR vim
alias rm='rm -i'
alias v='open -a /Applications/MacVim.app'
alias mvim='open -a /Applications/MacVim.app'
alias vimr='/usr/local/lib/vimr'
alias o='open -a /Applications/VimR.app'
alias ll='ls -l'

export MANPAGER="col -b | mvim -c 'set ft=man ts=8 nomod nolist nonu' -c 'nnoremap i <nop>' -"

alias cdp='cd ~/Documents/Projects/'
alias cdb='cd ~/Documents/Beremiz/'
alias cdl='cd ~/Documents/Libs/'
alias cdd='cd ~/Documents/Documents/'
alias cdz='cd ~/Downloads/'
alias ctr='ctags -R --languages=c,c++'
alias config='open -a /Applications/MacVim.app ~/.bashrc ~/.config/fish/config.fish ~/.vimrc ~/.config/nvim/init.vim ~/.config/karabiner/karabiner.json'
# alias ctags="/usr/local/Cellar/ctags/5.8_1/bin/ctags"
# alias ctags="ctags -R *.c"
# [ -f ~/.fzf.bash ] && source ~/.fzf.bash
