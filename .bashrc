export EDITOR='nvim'
# Don't save history if leading space 
export HISTCONTROL='ignorespace'
alias r='ranger'
alias rm='rm -i'
alias vi='vim -u ~/.vimrc_'
alias sudo='sudo '

export MANPAGER="/bin/sh -c \"col -b | nvim -c 'set ft=man ts=8 nomod nolist nornu noma' -\""

if [[ $(uname -s) == Linux ]]
then
    alias v='nvim'
    alias ls='ls --color -h --group-directories-first'
    alias ll='ls -lh -G --color -h --group-directories-first'
    alias cdp='cd /media/psf/Home/Documents/Projects/'
    alias cdb='cd /media/psf/Home/Documents/Beremiz/'
    alias cdl='cd /media/psf/Home/Documents/Libs/'
    alias cdd='cd /media/psf/Home/Documents/Documents/'
    alias cdz='cd /media/psf/Home/Downloads/'
else
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
fi

