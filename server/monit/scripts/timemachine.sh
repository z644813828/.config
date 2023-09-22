#!/bin/bash

dt1=$(tail -7 /sharedfolders/TimeMachine/MacBook\ Pro.sparsebundle/com.apple.TimeMachine.SnapshotHistory.plist | head -1)
dt1=$(echo $dt1 | awk '{ print substr ( $0, 7 ) }')
dt1=$(echo $dt1 | awk '{ print substr( $0, 1, length($0)-7 ) }')

t1=$(date --date="$dt1" +%s)
dt2=$(date +%Y-%m-%d\ %H:%M:%S)
t2=$(date --date="$dt2" +%s)

let "tDiff=$t2-$t1"
let "hDiff=$tDiff/3600"
let "mDiff=$tDiff%3600/60"
let "sDiff=$tDiff%60"

echo "$hDiff:$mDiff:$sDiff wihout backups!!!"

if (( $hDiff > 48 )); then
    exit 1
fi

exit 0
