#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

dirs=()
dirs+=(~/Documents/Projects/myproject)

for dir in "${dirs[@]}"; do
    cd $dir
    git clean -xfd > /dev/null 2>&1
    git remote update > /dev/null 2>&1
    ret=$(git status)
    if [[ $ret != *"On branch master"* ]]; then
        printf "${RED}%-60s%s${NC}\n" "$dir" "ERR Not master branch"
    elif [[ $ret == *"Your branch is behind"* ]]; then
        printf "${YELLOW}%-60s%s${NC}\n" "$dir" "Can be updated";
        printf "Git pull? [Y/n]:  "
        read S
        if [[ "$S" == "n" ]]; then
            echo;
        elif [[ "$S" == "N" ]]; then
            echo;
        else
            git pull;
        fi
    elif [[ $ret == *"Changes not staged for commit"* ]]; then
        printf "${RED}%-60s%s${NC}\n" "$dir" "ERR"
        git status --short
        printf "Git diff? [Y/n]:  "
        read S
        if [[ "$S" == "n" ]]; then
            echo;
        elif [[ "$S" == "N" ]]; then
            echo;
        else
            git diff;
        fi
    elif [[ $ret == *"Your branch is up to date"* ]]; then
        printf "${GREEN}%-60s%s${NC}\n" "$dir" "Up to date"
    else
        printf "${RED}%-60s%s${NC}\n" "$dir" "ERR"
        git status
    fi
done

