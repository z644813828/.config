# {{{ Shell environment variables
set -U _USER "dmitriy"
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

switch (uname)
case Linux
    set -x TOOLCHAINS_PATH "/home/$_USER/Documents/Libs/_Toolchain"
case Darwin
    set -x TOOLCHAINS_PATH "/Users/$_USER/Documents/Libs/_Toolchain"
end

# }}} 

# {{{ Extensions path
# Not to dublicate extentions for root and main user
switch (uname)
case Linux
    set fish_function_path /home/$_USER/.config/fish/functions $fish_function_path
case Darwin
    set fish_function_path /Users/$_USER/.config/fish/functions $fish_function_path
end
# }}} 

# {{{ Install fisher plugin manager and packages if not exist
function PlugInstall
    set -x plugins_list
    set -a plugins_list "oh-my-fish/theme-bobthefish"       # Prompt theme
    set -a plugins_list "jethrokuan/fzf"                    # Improved fzf-integration
    set -a plugins_list "laughedelic/pisces"                # Helper for pairing simbols
    set -a plugins_list "oh-my-fish/plugin-bang-bang"       # Bash style history substitution
    set -a plugins_list "oh-my-fish/plugin-grc"             # Code highlighting
    set -a plugins_list "jethrokuan/z"                      # Z port for fish
    set -a plugins_list "jorgebucaran/getopts.fish"         # Parse CLI options
    set -a plugins_list "edc/bass"                          # bash commands compatibility
    # set -a plugins_list "oh-my-fish/plugin-brew"          # Integrate Homebrew paths into shell 
    # set -a plugins_list "aughedelic/brew-completions"     # Homebrew completions
    # set -a plugins_list "oh-my-fish/plugin-local-config"  # Support different config files
    for i in $plugins_list; fisher install $i; end
    fish_reload
end

# if test uname = Darwin # not sure about install path on Linux/MacOS
if not functions -q fisher
    set -q XDG_CONFIG_HOME; or set XDG_CONFIG_HOME ~/.config
    curl https://git.io/fisher --create-dirs -sLo $XDG_CONFIG_HOME/fish/functions/fisher.fish
    fish -c PlugInstall
end
# end
# }}} 


# {{{ Aliases and functions

# {{{ All systems

set -U fish_key_bindings fish_default_key_bindings

# {{{ Linked Linux VM to MacOS /Users/dmitriy directory
# ln -s /media/psf/Home/{Documents,Desktop,Downloads,Pictures} ~
# ln -s /media/psf/Home/ /Users/dmitriy
abbr cdp ' cd ~/Documents/Projects/'
abbr cdb ' cd ~/Documents/Beremiz/'
abbr cdl ' cd ~/Documents/Libs/'
abbr cdd ' cd ~/Documents/Documents/'
abbr cdz ' cd ~/Downloads/'
# }}}

# {{{ SUDO wrapper
# If need to execute function from root, written as alias, fe `sudo r`
function sudo 
    command sudo -sE $argv 
end
abbr sf " sudo fish"
# }}}

# {{{ Reload
function fish_reload
    set -l jobs_list (jobs)
    if test -n "$jobs_list"
        printf "\033[0;31m Error!\033[0m \n"
        jobs
        return 1;
    else
        source $HOME/.config/fish/config.fish
        if count $argv > /dev/null
            set -x PROMPT $argv;
        end
        printf "\033[0;32m Config reloaded !\033[0m \n"
        fish; kill -9 $fish_pid
    end
end

abbr R " fish_reload"

# }}}

# {{{ Generic
alias r='ranger'
abbr q ' exit'
abbr r ' ranger'
abbr g 'git'
alias rm='rm -i'
alias vi="/usr/bin/vim"
alias v 'nvim'
alias vim 'nvim'
alias vimdiff='nvim -d'
alias vim-='nvim -R -'
set -a NPROC (nproc)
abbr jmake "make -j$NPROC"
abbr -- - 'cd -'
abbr fg ' fg'
bind \cx 'fg; commandline -f repaint'
# }}}

# {{{ Toolchain
function toolchain
    if test "$argv" = "auto"
        switch (basename $PWD)
        case "path1" , "path2"
            toolchain TOOLCHAIN_NAME_HERE
        end
        return
    end
    if test -e $TOOLCHAINS_PATH/$argv && count $argv > /dev/null
        export TOOLCHAIN=$argv
        set -a L_PATH "$TOOLCHAINS_PATH/$argv/lib"
        set -a H_PATH "$TOOLCHAINS_PATH/$argv/include/"
        printf "\033[0;32m Include path: \033[0m $H_PATH \n"
        printf "\033[0;32m Library path: \033[0m $L_PATH \n"
    else
        export TOOLCHAIN=""
        set -a L_PATH ""
        set -a H_PATH ""
        printf "\033[0;31m Error!\033[0m Toolchain not found: "
        ls $TOOLCHAINS_PATH/ --ignore="*tags"
    end
        export CPATH=$H_PATH
        export C_FLAGS=$H_PATH
        export LIBRARY_PATH=$L_PATH
        export LD_LIBRARY_PATH=$L_PATH
end
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
    # {{{ Atom
    function _atom
        if count $argv > /dev/null
            atom $argv
        else
            atom .
        end
    end
    alias a='_atom'
    # }}}

    # {{{ Wakeonlan 
    function wakeonlan
        # set -a MAC_ADDR FA:EB:DC:CD:BE:AF # example
        set -a MAC_ADDR 50:EB:F6:2C:44:63 # Z-home
        set -a MAC_ADDR 84:16:F9:05:75:85 # Server
        set -a MAC_ADDR 70:8B:CD:7F:25:A9 # Work
        if not string match --quiet --regex '\D' $argv
            if [ $argv -gt (count $MAC_ADDR) ]
                printf "\033[0;31m Error! $argv not in list:\033[0m \n"
                echo -e $MAC_ADDR | tr ' ' '\n'
            else
                eval command wakeonlan $MAC_ADDR[$argv]
            end
        else 
            command wakeonlan $argv
        end
    end
    # }}} 

    # {{{ Get program identifier
    function get_identifier
        if not test -d /Applications/$argv.app
            printf "\033[0;31m Error!\033[0m Program no found\n"
        else
            set cmd '/usr/libexec/PlistBuddy -c \'Print CFBundleIdentifier\' /Applications/'$argv'.app/Contents/Info.plist'
            echo $cmd
            eval command $cmd
        end
    end
    # }}} 

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
    
    # {{{ SSHFS with password from `~/.ssh/config` and flags
    function sshfs
        command $SCRIPTS/sshfs.sh $argv
    end
    # }}}

    # {{{ SCP with password from `~/.ssh/config`
    # function scp
        # command $SCRIPTS/scp.sh $argv
    # end
    # }}}

    # {{{ SSH wrapper to connect to VM or run a command
    function s
        set -U path (string replace -a ' ' '\\ ' $PWD)
        if count $argv > /dev/null
            command ssh -Xo LogLevel=QUIET -t $_USER@$VM_DEBIAN_1 "cd $path; $argv"
        else
            command ssh -Xt $_USER@$VM_DEBIAN_1 "cd $path; echo "Connected to $VM_DEBIAN_1"; fish"
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
                command $SCRIPTS/ssh.sh $ip
                if test "$status" = 0 
                    break
                else
                    sleep 1
                end
            end
    end
    # }}}

    # {{{ Minicom wrapper
    abbr mminicom 'env LC_ALL=ru_RU.CP1251 sudo minicom -C ~/temp/minicom_log/(date +%Y.%m.%d-%H:%M:%S).log -8 -m --device'
    # }}}

    # {{{ SSH to extra VM
    alias s2='ssh -Xt $_USER@$VM_DEBIAN_2 "cd $PWD; echo "Connected to $VM_DEBIAN_2"; fish"'
    alias s3='ssh -Xt $_USER@$VM_DEBIAN_3 "cd $PWD; echo "Connected to $VM_DEBIAN_3"; fish"'
    alias s4='ssh -Xt $_USER@$VM_DEBIAN_4 "cd $PWD; echo "Connected to $VM_DEBIAN_4"; fish"'
    # }}}

    # {{{ JS minify
    function js_minify
        set input_file $argv
        set output_file $argv.min
        set compiler '/opt/compiler-latest/closure-compiler-v20200517.jar'
        set flags1 '--charset=UTF-8'
        set flags2 '--strict_mode_input=false' 
        echo java -jar \
            $compiler \
            $flags1 \
            --js $input_file \
            --js_output_file $output_file \
            $flags2
        echo ">>"
        java -jar \
            $compiler \
            $flags1 \
            --js $input_file \
            --js_output_file $output_file \
            $flags2
    end
    # }}}

    # {{{ ScrCPY 
    # https://github.com/Genymobile/scrcpy
    # adb tcpip 5555; 
    function sscrcpy
        if count $argv > /dev/null
            set ip (ssh -G $argv | grep "^hostname " | awk '{printf "%s", $2}')
            adb connect $ip:5555;
            scrcpy -s $ip:5555 --rotation 0 --turn-screen-off -b2M -m800 --max-fps 15
        else
            scrcpy --rotation 0 --turn-screen-off -b2M -m800 --max-fps 15
        end
    end
    # }}}

    # {{{ Other
    alias cdi='cd ~/Library/Mobile\ Documents/com~apple~CloudDocs'
    alias m='/Applications/MacVim.app/Contents/bin/mvim'
    alias m_cli='/usr/local/bin/m'
    alias mvim='/Applications/MacVim.app/Contents/bin/mvim'
    alias ls='gls -N --color -h --group-directories-first'
    alias ll='gls -N -lh -G --color -h --group-directories-first'
    alias ctr='ctags -R --languages=c,c++'
    alias config='/Applications/MacVim.app/Contents/bin/mvim ~/.config/{.bashrc, fish/config.fish, .vimrc, nvim/init.vim, karabiner/karabiner.json, install.sh, .tmux.conf}'
    alias cat='bat'
    abbr S '$SCRIPTS/'
    # }}}

    # {{{ Fork
    function fork
        if count $argv > /dev/null
            open $argv -a /Applications/Fork.app
        else
            open . -a /Applications/Fork.app
        end
    end
    # }}}

# }}}

# {{{ | Other
case '*'
    echo Unsupported system detected!
end
# }}}

# }}}

# {{{ dev/tty1
string match -r -q -- '/dev/tty[0-9]' (tty); and set -x PROMPT 0; and exit;
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
case toolchain
    # export TERM="dumb" # hmm... that's not working (functions/fish_prompt.fish:1048)
    function fish_prompt -d 'simple fish_prompt'
        printf "\033[0;32m $TOOLCHAIN\033[0m ▶ "
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
test -e {$HOME}/.iterm2_shell_integration.fish ; or curl -L https://iterm2.com/shell_integration/fish -o ~/.iterm2_shell_integration.fish
source {$HOME}/.iterm2_shell_integration.fish
# }}}


