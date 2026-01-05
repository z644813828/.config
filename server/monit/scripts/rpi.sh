#!/bin/bash

dt1=$(cat /var/log/rpi.log)
t1=$(date --date="$dt1" +%s)
dt2=$(date +%Y-%m-%d\ %H:%M:%S)
t2=$(date --date="$dt2" +%s)

let "tDiff=$t2-$t1"
let "hDiff=$tDiff/3600"
let "mDiff=$tDiff%3600/60"
let "sDiff=$tDiff%60"

echo "$hDiff:$mDiff:$sDiff wihout syncing!!!"

if (( $tDiff > 600)); then
    exit 1
fi

exit 0
