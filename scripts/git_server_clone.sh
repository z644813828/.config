#!/bin/bash

git=$1
path=$2
git clone git@server:/~/$git $path
if [[ -z "$path" ]]; then
    cd $git
else
    cd $path
fi
