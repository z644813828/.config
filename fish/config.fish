set fish_greeting
set -x EDITOR vim
# Don't save history if leading space 
set -x HISTCONTROL ignorespace ignoredups
set -x SCRIPTS ~/.config/scripts
alias r='ranger'
alias rm='rm -i'
alias vim-='vim -R -'
alias vi='vim -u ~/.vimrc_'

function sudo 
    command sudo -sE $argv 
end

export MANPAGER="/bin/sh -c \"col -b | vim -c 'set ft=man ts=8 nomod nolist nornu noma' -\""

# ln -s /media/psf/Home/{Documents,Desktop,Downloads,OneDrive,Pictures} ~
alias cdp='cd ~/Documents/Projects/'
alias cdb='cd ~/Documents/Beremiz/'
alias cdl='cd ~/Documents/Libs/'
alias cdd='cd ~/Documents/Documents/'
alias cdz='cd ~/Downloads/'
alias cdo='cd ~/OneDrive'

switch (uname)
case Linux
    alias v='vim'
    alias ls='ls --color -h --group-directories-first'
    alias ll='ls -lh -G --color -h --group-directories-first'
    alias config='cd /etc/monit; vim -p /etc/monit/{monitrc,conf.d/auth_log.conf,conf.d/daemon_log.conf,conf.d/messages.conf,conf.d/syslog.conf,ip_location.sh,whitelist_ips.regex}'

case Darwin

    function ssh
        command $SCRIPTS/ssh.sh $argv
    end

    function s
        if count $argv > /dev/null
            command ssh -o LogLevel=QUIET -t dmitriy@10.211.55.3 "cd $PWD; $argv"
        else
            command ssh -t dmitriy@10.211.55.3 "cd $PWD; echo "Connected to 10.211.55.3"; fish"

        end
    end

    alias s2='ssh -t dmitriy@10.211.55.4 "cd $PWD; echo "Connected to 10.211.55.4"; fish"'
    alias s3='ssh -t dmitriy@10.211.55.5 "cd $PWD; echo "Connected to 10.211.55.5"; fish"'
    alias s4='ssh -t dmitriy@10.211.55.6 "cd $PWD; echo "Connected to 10.211.55.6"; fish"'
    alias m='/Applications/MacVim.app/Contents/bin/mvim'
    alias m_cli='/usr/local/bin/m'
    alias mivm='/Applications/MacVim.app/Contents/bin/mvim'
    alias v='/usr/local/lib/vimr'
    alias a='atom'
    alias ls='gls --color -h --group-directories-first'
    alias ll='gls -lh -G --color -h --group-directories-first'
    alias ctr='ctags -R --languages=c,c++'
    alias config='/Applications/MacVim.app/Contents/bin/mvim ~/.config/{.bashrc, fish/config.fish, .vimrc, nvim/init.vim, karabiner/karabiner.json, install.sh, .tmux.conf}'
    alias browserosaurus='cd /usr/local/bin/browserosaurus/; bash -c -- "nohup yarn start &>/dev/null &"; cd -'
    alias cat='bat'

case '*'
    echo Unsupported system detected!
end

function fish_prompt
    switch (whoami)
        case root
            set_color red
        case '*'
            set_color $fish_color_cwd
    end
    if test "$PWD" = "$HOME" 
        echo "~ "
    else
        echo (basename $PWD) "> "
    end
end
