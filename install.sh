#!/bin/bash

USER="dmitriy"

client_ip=()
server_ip=()

client_ip+=(10.211.55.3 Debian)
client_ip+=(10.211.55.4 Debian_2)
client_ip+=(10.211.55.5 Debian_3)
client_ip+=(10.211.55.6 Debian_VPN)
client_ip+=(10.211.55.9 Debian_Clean)

server_ip+=(192.168.2.251 Rasbperry_PI)
server_ip+=(192.168.2.254 Server_OMV)
# server_ip+=(192.168.2.255 Server_2)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

INSTALL_PLUG="curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; \
        mkdir -p ~/.local/share/nvim/site/autoload/; \
        cp -r ~/.vim/autoload/plug.vim ~/.local/share/nvim/site/autoload; "

MKDIR="mkdir -p /home/$USER/.config/{fish,ranger,scripts,nvim}"

EXEC_USER="$INSTALL_PLUG \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim; \
        sed -i 's/(basename \$PWD) //g' ~/.config/fish/config.fish; \
        vim +PlugInstall +qall; nvim +PlugInstall +qall"
EXEC_ROOT="$INSTALL_PLUG \
        cp /home/$USER/{.vimrc,.bashrc,.tmux.conf} /root/; \
        cp /home/$USER/.config/fish/config.fish /root/.config/fish/"
EXEC_SERV="$INSTALL_PLUG \
        vim +PlugInstall +qall; nvim +PlugInstall +qall \
        sudo bash -c -- 'cp /home/$USER/{.vimrc,.bashrc,.tmux.conf} /root/; \
        cp /home/$USER/.config/fish/config.fish /root/.config/fish/; \
        cp -r /home/$USER/.config/nvim /root/.config/'"

SCP(){
    scp .vimrc $USER@$1:/home/$USER/
    scp .vimrc_ $USER@$1:/home/$USER/
    scp .bashrc $USER@$1:/home/$USER/
    scp .tmux.conf $USER@$1:/home/$USER/
    scp fish/config.fish $USER@$1:/home/$USER/.config/fish/
    scp -r nvim/* $USER@$1:/home/$USER/.config/nvim/
    scp ranger/* $USER@$1:/home/$USER/.config/ranger/
    scp -r scripts $USER@$1:/home/$USER/.config
}

EXEC_C(){
    hostname=$(ssh -G $1 | awk '/^hostname / { print $2 }')
    if ping -c 1 -W 1 $hostname &> /dev/null
    then
        printf "\n${GREEN}Connecting to ${YELLOW}$2 [$1]${GREEN} (client) ${NC}\n"
        ssh -t $USER@$1 $MKDIR
        SCP $1
        ssh -t $USER@$1 $EXEC_USER
        ssh -t root@$1 $EXEC_ROOT
    else
        printf "\n${RED}Host ${YELLOW}$2 [$1]${RED} (client) is unreachable!${NC}\n"
    fi
}

EXEC_S(){
    hostname=$(ssh -G $1 | awk '/^hostname / { print $2 }')
    if ping -c 1 -W 1 $hostname &> /dev/null
    then
        printf "\n${GREEN}Connecting to ${YELLOW}$2 [$1]${GREEN} (server) ${NC}\n"
        ssh -t $USER@$1 $MKDIR
        SCP $1
        ssh -t $USER@$1 $EXEC_SERV
    else
        printf "\n${RED}Host ${YELLOW}$2 [$1]${RED} (server) is unreachable!${NC}\n"
    fi
}

if [[ "$1" == "0" ]]; then
    printf "\n${GREEN}Installing on localhost${NC}\n"
    cp -r .vimrc .gvimrc .bashrc .tmux.conf ../
    cp -r .bashrc .tmux.conf ../.sshrc.d
    cp .vimrc_ ../.sshrc.d/.vimrc
    cp .vimrc_ ../
    vim +PlugInstall +qall
    nvim +PlugInstall +qall
elif [[ "$1" == "" ]]; then
    for (( i = 0; i < "${#client_ip[@]}"; i+=2 )); do
        EXEC_C ${client_ip[$i]} ${client_ip[$i+1]}
    done
    for (( i = 0; i < "${#server_ip[@]}"; i+=2 )); do
        EXEC_S ${server_ip[$i]} ${server_ip[$i+1]}
    done
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
