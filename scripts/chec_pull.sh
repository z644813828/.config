#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color
DATE="date +%Y.%m.%d-%H:%M:%S"
LOG_FILE="$HOME/temp/check_pull/$($DATE).md" 
mkdir -p $HOME/temp/check_pull

dirs=()
uptodate=()
updated=()
notupdated=()
error=()
# dirs+=(Projects/my_project                    master)

for (( i = 0; i < "${#dirs[@]}"; i+=2 )); do
    dir=${dirs[$i]}
    branch=${dirs[$i+1]}
    cd ~/Documents/$dir
    git clean -Xf > /dev/null 2>&1
    git remote update > /dev/null 2>&1
    ret=$(git status)
    if [[ $ret != *"On branch $branch"* ]]; then
        printf "${RED}%-60s%s${NC}\n" "$dir" "ERR Not $branch branch"
        error+=($dir)
    elif [[ $ret == *"Your branch is behind"* ]]; then
        printf "${YELLOW}%-60s%s${NC}\n" "$dir" "Can be updated";
        printf "Git pull? [Y/n]:  "
        read S
        if [[ "$S" == "n" ]]; then
            notupdated+=($dir)
            echo;
        elif [[ "$S" == "N" ]]; then
            notupdated+=($dir)
            echo;
        else
            updated+=($dir)
            git pull;
        fi
    elif [[ $ret == *"Your branch is ahead"* ]]; then
        printf "${YELLOW}%-60s%s${NC}\n" "$dir" "Can be published";
        error+=($dir)
    elif [[ $ret == *"Changes not staged for commit"* ]]; then
        printf "${RED}%-60s%s${NC}\n" "$dir" "ERR"
        git status --short
        error+=($dir)
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
        uptodate+=($dir)
        printf "${GREEN}%-60s%s${NC}\n" "$dir" "Up to date"
    else
        printf "${RED}%-60s%s${NC}\n" "$dir" "ERR"
        error+=($dir)
        git status
    fi
done

echo
echo
echo
len=${#uptodate[@]}
echo "Up to date  :  $len projects" 
echo "# Up to date  :  $len projects" >> $LOG_FILE
for (( i=0; i<$len; i++ )); do 
    echo "- " ${uptodate[$i]} >> $LOG_FILE;
    printf "${GREEN}%s${NC}\n" "${uptodate[$i]}" ;
done
echo 

len=${#updated[@]}
echo "Updated     :  $len projects"
echo "# Updated     :  $len projects" >> $LOG_FILE
for (( i=0; i<$len; i++ )); do 
    echo "- " ${updated[$i]} >> $LOG_FILE;
    printf "${YELLOW}%s${NC}\n" "${updated[$i]}" | $LOG;
done
echo

len=${#notupdated[@]}
echo "Not updated :  $len projects"
echo "# Not updated :  $len projects" >> $LOG_FILE
for (( i=0; i<$len; i++ )); do 
    echo "- " ${notupdated[$i]} >> $LOG_FILE;
    printf "${YELLOW}%s${NC}\n" "${notupdated[$i]}" ;
done
echo

len=${#error[@]}
echo "Error       :  $len projects"
echo "# Error       :  $len projects" >> $LOG_FILE
for (( i=0; i<$len; i++ )); do 
    echo "- " ${error[$i]} >> $LOG_FILE;
    printf "${RED}%s${NC}\n" "${error[$i]}" ;
done
echo

