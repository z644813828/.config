#!/bin/bash

ssh -o LogLevel=QUIET -t git@server '\
    for i in *; do \
        cd $i; \
        x=$(git log -1 --pretty=format:"%h - %an, %ar : %s"); \
        printf "%-15s\t" $i; \
        echo $x; \
        cd; \
    done'
