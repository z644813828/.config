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

args=" -o volname=$host,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,auto_xattr,dev,suid,defer_permissions,noappledouble,noapplexattr"
cmd="mkdir -p ~/sshfs/$host && sshfs -p $port root@$ip:$path ~/sshfs/$host $args"
echo $cmd
# 
# password=`awk "/#Password/ && inhost { print \\\$2 } /Host/ { inhost=0 } /Host $host/ { inhost=1 }" ~/.ssh/config`
# if [[ -n "$password" ]]; then cmd=$cmd" <<< $password"; fi

bash -c "$cmd"
