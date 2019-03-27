set fish_greeting
set -x EDITOR vim
# Don't save history if leading space 
set -x HISTCONTROL ignorespace
alias r='ranger'
alias rm='rm -i'

export MANPAGER="/bin/sh -c \"col -b | vim -c 'set ft=man ts=8 nomod nolist nornu noma' -\""

switch (uname)
case Linux
    alias v='vim'
    alias ls='ls --color -h --group-directories-first'
    alias ll='ls -lh -G --color -h --group-directories-first'
    alias cdp='cd /media/psf/Home/Documents/Projects/'
    alias cdb='cd /media/psf/Home/Documents/Beremiz/'
    alias cdl='cd /media/psf/Home/Documents/Libs/'
    alias cdd='cd /media/psf/Home/Documents/Documents/'
    alias cdz='cd /media/psf/Home/Downloads/'
case Darwin
    alias s="echo 'Connected to 10.211.55.3';ssh -X -t dmitriy@10.211.55.3 fish"
    alias m='open -a /Applications/MacVim.app'
    alias v='/usr/local/lib/vimr'
    alias ls='gls --color -h --group-directories-first'
    alias ll='gls -lh -G --color -h --group-directories-first'
    alias cdp='cd ~/Documents/Projects/'
    alias cdb='cd ~/Documents/Beremiz/'
    alias cdl='cd ~/Documents/Libs/'
    alias cdd='cd ~/Documents/Documents/'
    alias cdz='cd ~/Downloads/'
    alias ctr='ctags -R --languages=c,c++'
    alias config='open -a /Applications/MacVim.app ~/.config/.bashrc ~/.config/fish/config.fish ~/.config/.vimrc ~/.config/nvim/init.vim ~/.config/karabiner/karabiner.json'
case '*'
    echo Unsupported system detected!
end

function fish_prompt
  set_color $fish_color_cwd
  echo (basename $PWD) "> "
  # echo (eval $PWD) "> "
end
