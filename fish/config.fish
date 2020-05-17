set fish_greeting
set -x EDITOR nvim
# Don't save history if leading space 
set -x HISTCONTROL ignorespace ignoredups
set -x SCRIPTS ~/.config/scripts
alias r='ranger'
alias rm='rm -i'
alias vi='vim -u ~/.vimrc_'
abbr vim 'nvim'
alias vimdiff='nvim -d'
alias vim-='nvim -R -'
abbr -- - 'cd -'

function sudo 
    command sudo -sE $argv 
end

export MANPAGER="/bin/sh -c \"col -b | nvim -c 'set ft=man ts=8 nomod nolist nornu noma' -\""

# ln -s /media/psf/Home/{Documents,Desktop,Downloads,OneDrive,Pictures} ~
abbr cdp 'cd ~/Documents/Projects/'
abbr cdb 'cd ~/Documents/Beremiz/'
abbr cdl 'cd ~/Documents/Libs/'
abbr cdd 'cd ~/Documents/Documents/'
abbr cdz 'cd ~/Downloads/'
abbr cdo 'cd ~/OneDrive'

switch (uname)
case Linux
    alias v='nvim'
    alias ls='ls --color -h --group-directories-first'
    alias ll='ls -lh -G --color -h --group-directories-first'
    alias config='cd /etc/monit; nvim -p /etc/monit/{monitrc,conf.d/auth_log.conf,conf.d/daemon_log.conf,conf.d/messages.conf,conf.d/syslog.conf,ip_location.sh,whitelist_ips.regex}'
    function pvs 
        eval $SCRIPTS/pvs.sh $argv
    end

    function ddu 
        command du -sk $argv | sort -nr | cut -f2 | xargs -d '\n' du -sh 
    end


case Darwin

    function check_pull
        if count $argv > /dev/null
            git remote update
            git status
        else
            command $SCRIPTS/chec_pull.sh $argv
        end
    end
    
    function git_server_new
        command $SCRIPTS/git_server_new.sh $argv
    end

    function git_server_list
        command $SCRIPTS/git_server_list.sh
    end
    function git_server_clone
        command $SCRIPTS/git_server_clone.sh $argv
    end

    function ssh
        command $SCRIPTS/ssh.sh $argv
    end

    function s
        if count $argv > /dev/null
            command ssh -Xo LogLevel=QUIET -t dmitriy@10.211.55.3 "cd $PWD; $argv"
        else
            command ssh -Xt dmitriy@10.211.55.3 "cd $PWD; echo "Connected to 10.211.55.3"; fish"
        end
    end

    function sssh
        if count $argv > /dev/null
            set ip $argv
        else
            set ip 10.211.55.3
        end
            while true; 
                command ~/.config/scripts/ssh.sh "$ip"; 
                if test "$status" = 0 
                    break
                else
                    sleep 1
                end
            end
    end

    function mminicom
        env LC_ALL=ru_RU.CP1251 sudo minicom -C ~/temp/minicom_log/(date +%Y.%m.%d-%H:%M:%S) -8 -m --device $argv 
    end

    alias s2='ssh -Xt dmitriy@10.211.55.4 "cd $PWD; echo "Connected to 10.211.55.4"; fish"'
    alias s3='ssh -Xt dmitriy@10.211.55.5 "cd $PWD; echo "Connected to 10.211.55.5"; fish"'
    alias s4='ssh -Xt dmitriy@10.211.55.6 "cd $PWD; echo "Connected to 10.211.55.6"; fish"'
    alias m='/Applications/MacVim.app/Contents/bin/mvim'
    alias m_cli='/usr/local/bin/m'
    alias mvim='/Applications/MacVim.app/Contents/bin/mvim'
    alias v='/usr/local/lib/vimr'
    alias a='atom'
    alias ls='gls --color -h --group-directories-first'
    alias ll='gls -lh -G --color -h --group-directories-first'
    alias ctr='ctags -R --languages=c,c++'
    alias config='/Applications/MacVim.app/Contents/bin/mvim ~/.config/{.bashrc, fish/config.fish, .vimrc, nvim/init.vim, karabiner/karabiner.json, install.sh, .tmux.conf}'
    alias cat='bat'
    abbr S '$SCRIPTS/'

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

test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish

