#!/bin/bash

USER="dmitriy"

client_ip=()
server_ip=()

client_ip+=(10.211.55.3 Debian VM)
client_ip+=(10.211.55.4 Debian_2 VM)
client_ip+=(10.211.55.5 Debian_3 VM)
client_ip+=(10.211.55.6 Debian_VPN VM)
client_ip+=(10.211.55.9 Debian_Clean PC)
client_ip+=(192.168.2.131 Laptop_2 PC)

server_ip+=(192.168.2.251 Rasbperry_PI)
server_ip+=(192.168.2.254 Server_OMV)
# server_ip+=(192.168.2.255 Server_2)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

EXEC_USER="bash -c -- 'vim +PlugInstall +qall; nvim +PlugInstall +qall'"
EXEC_SERV="sudo bash -c -- ' bash -c -- 'vim +PlugInstall +qall; nvim +PlugInstall +qall'"

LNS_FILE_LIST=(.bashrc .gvimrc .tmux.conf .vimrc .vimrc_ .config/fish/config.fish .config/nvim .config/ranger .config/scripts)


SCP(){
    scp .vimrc $USER@$1:/home/$USER/
    scp .vimrc_ $USER@$1:/home/$USER/
    scp .bashrc $USER@$1:/home/$USER/
    scp .tmux.conf $USER@$1:/home/$USER/
    scp -r fish/{config.fish,fishfile} $USER@$1:/home/$USER/.config/fish/
    scp -r nvim $USER@$1:/home/$USER/.config/
    scp -r ranger $USER@$1:/home/$USER/.config/
    scp -r scripts $USER@$1:/home/$USER/.config/
}


LNS_BUILD_CMD_VM(){
    LNS_CMD="echo"
    for file in ${LNS_FILE_LIST[*]}
    do
        LNS_CMD="${LNS_CMD} && ln -sf /Users/$USER/$file /home/$USER/$file"
    done
}

LNS_BUILD_CMD_ROOT(){
    LNS_CMD="echo"
    for file in ${LNS_FILE_LIST[*]}
    do
        LNS_CMD="${LNS_CMD} && ln -sf /home/$USER/$file /root/$file"
    done
}

EXEC_C(){
    hostname=$(ssh -G $1 | awk '/^hostname / { print $2 }')
    if ping -c 1 -W 1 $hostname &> /dev/null
    then
        printf "\n${GREEN}Connecting to ${YELLOW}$2 [$1]${GREEN} (client) ${NC}\n"
        if [[ "$3" == "VM" ]]; then
            LNS_BUILD_CMD_VM
            ssh -t $USER@$1 "rm -rf ${LNS_FILE_LIST[@]}; $LNS_CMD; $EXEC_USER"
            LNS_BUILD_CMD_ROOT
            ssh -t root@$1 "rm -rf ${LNS_FILE_LIST[@]}; $LNS_CMD"
        else
            SCP $1
            ssh -t $USER@$1 $EXEC_USER
            LNS_BUILD_CMD_ROOT
            ssh -t root@$1 "rm -rf ${LNS_FILE_LIST[@]}; $LNS_CMD"
        fi
    else
        printf "\n${RED}Host ${YELLOW}$2 [$1]${RED} (client) is unreachable!${NC}\n"
    fi
}

EXEC_S(){
    hostname=$(ssh -G $1 | awk '/^hostname / { print $2 }')
    if ping -c 1 -W 1 $hostname &> /dev/null
    then
        printf "\n${GREEN}Connecting to ${YELLOW}$2 [$1]${GREEN} (server) ${NC}\n"
        SCP $1
        LNS_BUILD_CMD_ROOT
        ssh -t $USER@$1 "sudo bash -c 'rm -rf ${LNS_FILE_LIST[@]}; $LNS_CMD; $EXEC_SERV'; $EXEC_USER"
    else
        printf "\n${RED}Host ${YELLOW}$2 [$1]${RED} (server) is unreachable!${NC}\n"
    fi
}

if [[ "$1" == "0" ]]; then
    printf "\n${GREEN}Installing on localhost${NC}\n"
    ln -sf ~/.config/.vimrc ~
    ln -sf ~/.config/.vimrc_ ~
    ln -sf ~/.config/.gvimrc ~
    ln -sf ~/.config/.bashrc ~
    ln -sf ~/.config/.tmux.conf ~
    mkdir -p ~/.sshrc.d
    ln -sf ~/.bashrc ~/.sshrc.d/
    ln -sf ~/.tmux.conf ~/.sshrc.d/
    vim +PlugInstall +qall
    nvim +PlugInstall +qall
elif [[ "$1" == "" ]]; then
    for (( i = 0; i < "${#client_ip[@]}"; i+=3 )); do
        EXEC_C ${client_ip[$i]} ${client_ip[$i+1]} ${client_ip[$i+2]}
    done
    for (( i = 0; i < "${#server_ip[@]}"; i+=2 )); do
        EXEC_S ${server_ip[$i]} ${server_ip[$i+1]}
    done
else
    printf "Enter [c/s] [client/server]: "
    read S
    if [[ "$S" == "c" ]]; then
        printf "Enter [VM/PC] [parallels/real pc]: "
        read P
        EXEC_C $1 0 $P
    elif [[ "$S" == "s" ]]; then
        EXEC_S $1
    else
        echo Unsupported case
    fi
fi
