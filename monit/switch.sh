#!/bin/bash
switch=$1
file="/var/log/server2.log"
state=$(tail -n 1 $file)
if [[ $switch != $state ]]; then
  echo $switch >> $file
fi
