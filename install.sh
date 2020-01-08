#!/bin/bash

EXEC_USER="curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; \
        sed -i 's/(basename \$PWD) //g' ~/.config/fish/config.fish; \
        vim +PlugInstall +qall"
EXEC_ROOT="curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; \
        cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; \
        cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/"
EXEC_SERV="vim +PlugInstall +qall; \
        sudo bash -c -- 'cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; \
        cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/'"

SCP(){
    scp .vimrc dmitriy@$1:/home/dmitriy/
    scp .vimrc_ dmitriy@$1:/home/dmitriy/
    scp .bashrc dmitriy@$1:/home/dmitriy/
    scp .tmux.conf dmitriy@$1:/home/dmitriy/
    scp fish/config.fish dmitriy@$1:/home/dmitriy/.config/fish/
    scp ranger/* dmitriy@$1:/home/dmitriy/.config/ranger/
    scp -r scripts dmitriy@$1:/home/dmitriy/.config
}

EXEC_C(){
    if ping -c 1 -W 1 $1 &> /dev/null
    then
        SCP $1
        ssh -t dmitriy@$1 $EXEC_USER
        ssh -t root@$1 $EXEC_ROOT
    else
        echo host $1 unreachable 
    fi
}

EXEC_S(){
    if ping -c 1 -W 1 $1 &> /dev/null
    then
        SCP $1
        ssh -t dmitriy@$1 $EXEC_SERV
    else
        echo host $1 unreachable 
    fi
}

if [[ "$1" == "0" ]]; then
    cp -r .vimrc .gvimrc .bashrc .tmux.conf ../
    cp -r .bashrc .tmux.conf ../.sshrc.d
    cp .vimrc_ ../.sshrc.d/.vimrc
    cp .vimrc_ ../
    vim +PlugInstall +qall
    nvim +PlugInstall +qall
elif [[ "$1" == "" ]]; then
    # Parallels 
    EXEC_C 10.211.55.3
    EXEC_C 10.211.55.4
    EXEC_C 10.211.55.5
    EXEC_C 10.211.55.6
    # PI 
    EXEC_S 192.168.2.220
    # Server 
    EXEC_S 192.168.2.254
    # EXEC_S 192.168.2.255
else
    printf "Enter [c/s] [client/server]: "
    read S
    if [[ "$S" == "c" ]]; then
        EXEC_C $1
    elif [[ "$S" == "s" ]]; then
        EXEC_S $1
    else
        echo Unsupported case
    fi
fi
