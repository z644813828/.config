#!/bin/bash
switch=$1
if [[ "$switch" != "-q" ]]; then 
    sshfs "$@"
    exit
fi
host=$2
path=$3
if [[ -z "$path" ]]; then path="/"; fi

ip=`ssh -G $host | grep "^hostname " | awk '{printf "%s", $2}'`
port=`ssh -G $host | grep "^port " | awk '{printf "%s", $2}'`
user=`ssh -G $host | grep "^user " | awk '{printf "%s", $2}'`

args=" -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,dev,suid"
[[ $OSTYPE == 'darwin'* ]] && args=$args,auto_xattr,defer_permissions,noappledouble,noapplexattr

cmd="mkdir -p ~/sshfs/$host && sshfs -p $port $user@$ip:$path /Users/dmitriy/sshfs/$host $args"
echo $cmd

bash -c "$cmd"
