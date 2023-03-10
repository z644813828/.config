#!/bin/bash
switch=$2
file="/var/log/"$1".log"
state=$(tail -n 1 $file)
if [[ $switch != $state ]]; then
  echo $switch >> $file
fi
