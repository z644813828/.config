#!/bin/bash

git=$1
ret=$(ssh -o LogLevel=QUIET -t git@server "mkdir $git; cd $git")
if [[ $ret == *"mkdir"* ]]; then
    echo "ERROR: folder $git exist"
    exit;
fi
ssh -o LogLevel=QUIET -t git@server "cd $git; git init --bare; git config --bool core.bare true"

git clone git@server:/~/$git
cd $git
