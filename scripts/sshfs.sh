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

args=" -o password_stdin,reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,defer_permissions,noappledouble,IdentityFile=$HOME/.ssh/id_rsa"
cmd="mkdir -p /Volumes/$host && sshfs -p "$port"  "$args"  "$ip:$path" /Volumes/"$host
echo $cmd

password=`awk "/#Password/ && inhost { print \\\$2 } /Host/ { inhost=0 } /Host $host/ { inhost=1 }" ~/.ssh/config`
if [[ -n "$password" ]]; then cmd=$cmd" <<< $password"; fi

sudo bash -c "$cmd"
