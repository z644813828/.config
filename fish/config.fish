# {{{ Shell environment variables
# Default editor in system
set -x EDITOR nvim
# Don't save history if leading space 
set -x HISTCONTROL ignorespace ignoredups
# Bash scripts path, used by fish
set -x SCRIPTS ~/.config/scripts

export MANPAGER="/bin/sh -c \"col -b | $EDITOR -c 'set ft=man ts=8 nomod nolist nornu noma' -\""

export BAT_THEME="base16"

set -x VM_DEBIAN_1 "10.211.55.3"
set -x VM_DEBIAN_2 "10.211.55.4"
set -x VM_DEBIAN_3 "10.211.55.5"
set -x VM_DEBIAN_4 "10.211.55.6"

# }}} 

# {{{ Extensions path
# Not to dublicate extentions for root and main user
switch (uname)
case Linux
    set fish_function_path /home/dmitriy/.config/fish/functions $fish_function_path
case Darwin
    set fish_function_path /Users/dmitriy/.config/fish/functions $fish_function_path
end
# }}} 

# {{{ Install fisher plugin manager and packages if not exist
# if test uname = Darwin # not sure about install path on Linux/MacOS
if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c fisher
end
# end
# }}} 


# {{{ Aliases and functions

# {{{ All systems

set -U fish_key_bindings fish_default_key_bindings

# {{{ Linked Linux VM to MacOS /Users/dmitriy directory
# ln -s /media/psf/Home/{Documents,Desktop,Downloads,Pictures} ~
abbr cdp 'cd ~/Documents/Projects/'
abbr cdb 'cd ~/Documents/Beremiz/'
abbr cdl 'cd ~/Documents/Libs/'
abbr cdd 'cd ~/Documents/Documents/'
abbr cdz 'cd ~/Downloads/'
# }}}

# {{{ SUDO wrapper
# If need to execute function from root, written as alias, fe `sudo r`
function sudo 
    command sudo -sE $argv 
end
# }}}

# {{{ Reload
function fish_reload
    set jobs_list (jobs)
    if test $jobs_list
        echo "Error active jobs;" 
        echo $jobs_list
        return 1;
    else
        source $HOME/.config/fish/config.fish
        if count $argv > /dev/null
            set -x PROMPT $argv;
        end
        echo "Config reloaded"
        fish; kill -9 $fish_pid
    end
end

abbr R fish_reload

# }}}

# {{{ Generic
alias r='ranger'
abbr r 'ranger'
alias rm='rm -i'
alias vi="bash -c 'vim -u ~/.vimrc_'"
alias vim 'nvim'
alias vimdiff='nvim -d'
alias vim-='nvim -R -'
abbr -- - 'cd -'
# }}}

# }}} 

# OS depending 
switch (uname)

# {{{ | Linux
case Linux
# {{{ du with sort
function ddu 
    command du -sk $argv | sort -nr | cut -f2 | xargs -d '\n' du -sh 
end
# }}}

# {{{ Other 
    alias v='nvim'
    alias ls='ls --color -h --group-directories-first'
    alias ll='ls -lh -G --color -h --group-directories-first'
    alias config='cd /etc/monit; nvim -p /etc/monit/{monitrc,conf.d/auth_log.conf,conf.d/daemon_log.conf,conf.d/messages.conf,conf.d/syslog.conf,ip_location.sh,whitelist_ips.regex}'
    function pvs 
        eval $SCRIPTS/pvs.sh $argv
    end
# }}}

# }}} 

# {{{ | MacOS
case Darwin
    # {{{ Check new updates in project
    function check_pull
        if count $argv > /dev/null
            git remote update
            git status
        else
            command $SCRIPTS/chec_pull.sh $argv
        end
    end
    # }}}
    
    # {{{ Home server git manager
    function git_server_new
        command $SCRIPTS/git_server_new.sh $argv
    end
    function git_server_list
        command $SCRIPTS/git_server_list.sh
    end
    function git_server_clone
        command $SCRIPTS/git_server_clone.sh $argv
    end
    # }}}

    # {{{ Connect via sshpass with password from `~/.ssh/config`
    function ssh
        command $SCRIPTS/ssh.sh $argv
    end
    # }}}

    # {{{ SSH wrapper to connect to VM or run a command
    function s
        if count $argv > /dev/null
            command ssh -Xo LogLevel=QUIET -t dmitriy@$VM_DEBIAN_1 "cd $PWD; $argv"
        else
            command ssh -Xt dmitriy@$VM_DEBIAN_1 "cd $PWD; echo "Connected to $VM_DEBIAN_1"; fish"
        end
    end
    # }}}

    # {{{ SSH host status polling
    function sssh
        if count $argv > /dev/null
            set ip $argv
        else
            set ip $VM_DEBIAN_1
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
    # }}}

    # {{{ Minicom wrapper
    function mminicom
        env LC_ALL=ru_RU.CP1251 sudo minicom -C ~/temp/minicom_log/(date +%Y.%m.%d-%H:%M:%S) -8 -m --device $argv 
    end
    # }}}

    # {{{ SSH to extra VM
    alias s2='ssh -Xt dmitriy@$VM_DEBIAN_2 "cd $PWD; echo "Connected to $VM_DEBIAN_2"; fish"'
    alias s3='ssh -Xt dmitriy@$VM_DEBIAN_3 "cd $PWD; echo "Connected to $VM_DEBIAN_3"; fish"'
    alias s4='ssh -Xt dmitriy@$VM_DEBIAN_4 "cd $PWD; echo "Connected to $VM_DEBIAN_4"; fish"'
    # }}}

    # {{{ Other
    alias m='/Applications/MacVim.app/Contents/bin/mvim'
    alias m_cli='/usr/local/bin/m'
    alias mvim='/Applications/MacVim.app/Contents/bin/mvim'
    alias v='/usr/local/lib/vimr'
    alias a='atom'
    alias ls='gls -N --color -h --group-directories-first'
    alias ll='gls -N -lh -G --color -h --group-directories-first'
    alias ctr='ctags -R --languages=c,c++'
    alias config='/Applications/MacVim.app/Contents/bin/mvim ~/.config/{.bashrc, fish/config.fish, .vimrc, nvim/init.vim, karabiner/karabiner.json, install.sh, .tmux.conf}'
    alias cat='bat'
    abbr S '$SCRIPTS/'
    # }}}

# }}}

# {{{ | Other
case '*'
    echo Unsupported system detected!
end
# }}}

# }}}

# {{{ UI customization

# {{{ Prompt
# Export environment variable when using extern app, no patched font in ATOM etc
#
# possible states:
# default         # nerd fonts
# set -x PROMPT 0 # minimal prompt '▶'
# set -x PROMPT 1 # no pathed fonts
# set -x PROMPT 2 # patched fonts

# TODO: load from system 
switch (echo "$PROMPT")
case 0
    # export TERM="dumb" # hmm... that's not working (functions/fish_prompt.fish:1048)
    function fish_prompt -d 'simple fish_prompt'
        echo "▶ "
    end
case 1
    set -g theme_powerline_fonts no
case 2
    set -g theme_powerline_fonts yes
case '*'
    set -g theme_nerd_fonts yes
end


# }}}

# OS depending 
switch (uname)

# {{{ | Linux
case Linux
    set -g theme_display_git no
    set -g path_color white
# }}}

# {{{ | MacOS
case Darwin
    set -g theme_display_git yes
    set -g theme_display_git_dirty yes
    set -g theme_display_git_untracked no
    set -g theme_display_git_ahead_verbose no
    set -g theme_display_git_dirty_verbose no
    set -g theme_display_git_stashed_verbose no
    set -g theme_display_git_master_branch no
    set -g theme_git_worktree_support no
    set -g path_color black
# }}}
end

# {{{ Generic settings
set -g theme_display_user no
set -g theme_display_date no
set -g fish_prompt_pwd_dir_length 1
set -g theme_title_display_process yes
set -g theme_avoid_ambiguous_glyphs yes
set -g theme_display_jobs_verbose yes
set -g theme_display_sudo_user no
set -g theme_display_hostname ssh
set -g theme_color_scheme dark
function bobthefish_colors -S -d 'Define a custom bobthefish color scheme'
    set -x color_path                  $path_color
    set -x color_path_basename         $path_color
    set -x color_username              white
end
function fish_greeting; end
# }}}

# }}}


# {{{ FZF
set -U FZF_LEGACY_KEYBINDINGS 0

bind \ct '__fzf_open --editor'
if bind -M insert >/dev/null 2>/dev/null
    bind -M insert \ct '__fzf_open --editor'
end
bind \t '__fzf_complete'
if bind -M insert >/dev/null 2>/dev/null
    bind -M insert \t '__fzf_complete'
end

set -U FZF_FIND_FILE_COMMAND "ag -l --hidden --ignore .git \$dir 2> /dev/null"
set -U FZF_TMUX 0
set -U FZF_ENABLE_OPEN_PREVIEW 1
set -U FZF_CD_WITH_HIDDEN_OPTS 1
set -U FZF_COMPLETE 1
# set -U FZF_PREVIEW_FILE_CMD "highlight"
set FZF_PREVIEW_FILE_CMD "bat --color=always --style='plain' --line-range :100"
switch (uname)
case Linux
    set -U FZF_PREVIEW_DIR_CMD "ls -lh -G --color -h --group-directories-first"
case Darwin
    set -U FZF_PREVIEW_DIR_CMD "gls -lh -gG -N --color -h --group-directories-first"
end
# }}}

# {{{ Iterm iterm2_shell_integration.fish
test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish
# }}}


