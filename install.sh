#!/bin/bash

cp .vimrc ../
cp .bashrc ../

if ping -c 1 -W 1 10.211.55.3 &> /dev/null
then
    scp .vimrc dmitriy@10.211.55.3:/home/dmitriy/
    scp .bashrc dmitriy@10.211.55.3:/home/dmitriy/
    scp ~/.tmux.conf dmitriy@10.211.55.3:/home/dmitriy/
    scp fish/config.fish dmitriy@10.211.55.3:/home/dmitriy/.config/fish/
    ssh dmitriy@10.211.55.3 "sed -i 's/(basename \$PWD) //g' ~/.config/fish/config.fish"
    ssh root@10.211.55.3 "cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/"
else
  echo host 10.211.55.3 unreachable 
fi

if ping -c 1 -W 1 10.211.55.4 &> /dev/null
then
    scp .vimrc dmitriy@10.211.55.4:/home/dmitriy/
    scp .bashrc dmitriy@10.211.55.4:/home/dmitriy/
    scp ~/.tmux.conf dmitriy@10.211.55.4:/home/dmitriy/
    scp fish/config.fish dmitriy@10.211.55.4:/home/dmitriy/.config/fish/
    ssh dmitriy@10.211.55.4 "sed -i 's/(basename \$PWD) //g' ~/.config/fish/config.fish"
    ssh root@10.211.55.4 "cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/"
else
  echo host 10.211.55.4 unreachable 
fi

if ping -c 1 -W 1 10.211.55.5 &> /dev/null
then
    scp .vimrc dmitriy@10.211.55.5:/home/dmitriy/
    scp .bashrc dmitriy@10.211.55.5:/home/dmitriy/
    scp ~/.tmux.conf dmitriy@10.211.55.5:/home/dmitriy/
    scp fish/config.fish dmitriy@10.211.55.5:/home/dmitriy/.config/fish/
    ssh dmitriy@10.211.55.5 "sed -i 's/(basename \$PWD) //g' ~/.config/fish/config.fish"
    ssh root@10.211.55.5 "cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/"
else
  echo host 10.211.55.5 unreachable 
fi

if ping -c 1 -W 1 10.211.55.6 &> /dev/null
then
    scp .vimrc dmitriy@10.211.55.6:/home/dmitriy/
    scp .bashrc dmitriy@10.211.55.6:/home/dmitriy/
    scp ~/.tmux.conf dmitriy@10.211.55.6:/home/dmitriy/
    scp fish/config.fish dmitriy@10.211.55.6:/home/dmitriy/.config/fish/
    ssh dmitriy@10.211.55.6 "sed -i 's/(basename \$PWD) //g' ~/.config/fish/config.fish"
    ssh root@10.211.55.6 "cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/"
else
  echo host 10.211.55.6 unreachable 
fi

if ping -c 1 -W 1 192.168.2.254 &> /dev/null
then
    scp .vimrc dmitriy@192.168.2.254:/home/dmitriy/
    scp .bashrc dmitriy@192.168.2.254:/home/dmitriy/
    scp ~/.tmux.conf dmitriy@192.168.2.254:/home/dmitriy/
    scp fish/config.fish dmitriy@192.168.2.254:/home/dmitriy/.config/fish/
    echo Copy to root directory with cmd:
    echo 'cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/'
else
  echo host 192.168.2.254 unreachable 
fi

if ping -c 1 -W 1 192.168.2.255 &> /dev/null
then
    scp .vimrc dmitriy@192.168.2.255:/home/dmitriy/
    scp .bashrc dmitriy@192.168.2.255:/home/dmitriy/
    scp ~/.tmux.conf dmitriy@192.168.2.255:/home/dmitriy/
    scp fish/config.fish dmitriy@192.168.2.255:/home/dmitriy/.config/fish/
    echo Copy to root directory with cmd:
    echo 'cp /home/dmitriy/{.vimrc,.bashrc,.tmux.conf} /root/; cp /home/dmitriy/.config/fish/config.fish /root/.config/fish/'
else
  echo host 192.168.2.255 unreachable 
fi

