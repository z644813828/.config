#!/bin/bash

cp -r .vimrc .gvimrc .bashrc .tmux.conf ../

vim +PlugInstall +qall
nvim +PlugInstall +qall

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
    scp .bashrc dmitriy@$1:/home/dmitriy/
    scp .tmux.conf dmitriy@$1:/home/dmitriy/
    scp fish/config.fish dmitriy@$1:/home/dmitriy/.config/fish/
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

EXEC_C 10.211.55.3
EXEC_C 10.211.55.4
EXEC_C 10.211.55.5
EXEC_C 10.211.55.6

EXEC_S 192.168.2.254
EXEC_S 192.168.2.255
