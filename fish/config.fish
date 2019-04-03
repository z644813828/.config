set fish_greeting
set -x EDITOR vim
# Don't save history if leading space 
set -x HISTCONTROL ignorespace
alias r='ranger'
alias rm='rm -i'
alias vim-='vim -R -'

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
    # alias config='vim -p /etc/monit/{monitrc,conf.d/auth_log.conf,conf.d/daemon_log.conf,conf.d/messages.conf,conf.d/syslog.conf,ip_location.sh,whitelist_ips.regex}'
case Darwin
    alias s=' ssh -X -t dmitriy@10.211.55.3 "cd $PWD; echo "Connected to 10.211.55.3"; fish"'
    alias s2='ssh -X -t dmitriy@10.211.55.4 "cd $PWD; echo "Connected to 10.211.55.4"; fish"'
    alias s3='ssh -X -t dmitriy@10.211.55.5 "cd $PWD; echo "Connected to 10.211.55.5"; fish"'
    alias s4='ssh -X -t dmitriy@10.211.55.6 "cd $PWD; echo "Connected to 10.211.55.6"; fish"'
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
end
