alias r='ranger'
set -x EDITOR vim
alias rm='rm -i'
alias v="open -a /Applications/MacVim.app"
alias s="ssh -X -t dmitriy@10.211.55.3 'cd /;fish'"
alias mvim="open -a /Applications/MacVim.app"
# alias o oni
# alias o /usr/local/lib/vimr
alias o="open -a /Applications/VimR.app"
alias vimr="/usr/local/lib/vimr"
# alias o "/Applications/gonvim.app/Contents/MacOS/gonvim"

export MANPAGER="col -b | mvim -c 'set ft=man ts=8 nomod nolist nonu' -c 'nnoremap i <nop>' -"

alias cdp='cd ~/Documents/Projects/'
alias cdb='cd ~/Documents/Beremiz/'
alias cdl='cd ~/Documents/Libs/'
alias cdd='cd ~/Documents/Documents/'
alias cdz='cd ~/Downloads/'
alias ctr='ctags -R --languages=c,c++'
alias config='open -a /Applications/MacVim.app ~/.bashrc ~/.config/fish/config.fish ~/.vimrc ~/.config/nvim/init.vim ~/.config/karabiner/karabiner.json'

function fish_prompt
    set_color $fish_color_cwd
    echo (basename $PWD) "> "
end
