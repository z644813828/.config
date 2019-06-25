#!/bin/bash

host=$1
password=`awk "/#Password/ && inhost { print \\\$2 } /Host/ { inhost=0 } /Host $host/ { inhost=1 }" ~/.ssh/config`

if [[ -z "$password" ]]; then
  /usr/bin/ssh $*
else
  sshpass -p $password /usr/bin/ssh $*
fi

# Example:
# Host pi
#   User root
#   #Password 123
#   Port 222
#   HostName 127.0.0.1

