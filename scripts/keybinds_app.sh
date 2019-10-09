#!/bin/bash

# print all binded keys
PRINT_DOMAIN(){
    RET=$( { defaults read $i NSUserKeyEquivalents; } 2>&1 )
    if [[ $RET != *"does not exist"* ]]; then
        echo "********* READING DEFAULT DOMAIN $i **********"; 
        RET=$( echo $RET | sed 's/\\U/u/g' )
        RET=$( echo $RET | sed 's/\\uf704/F1/g' )
        RET=$( echo $RET | sed 's/\\uf705/F2/g' )
        RET=$( echo $RET | sed 's/\\uf706/F3/g' )
        RET=$( echo $RET | sed 's/\\uf707/F4/g' )
        RET=$( echo $RET | sed 's/\\uf708/F5/g' )
        RET=$( echo $RET | sed 's/\\uf709/F6/g' )
        RET=$( echo $RET | sed 's/\\uf710/F7/g' )
        RET=$( echo $RET | sed 's/\\uf711/F8/g' )
        RET=$( echo $RET | sed 's/\\uf712/F9/g' )
        RET=$( echo $RET | sed 's/\\uf713/F10/g' )
        RET=$( echo $RET | sed 's/\\uf714/F11/g' )
        RET=$( echo $RET | sed 's/\\uf715/F12/g' )
        RET=$( echo $RET | sed 's/\\\\\\\\/\\/g' )
        RET=$( echo $RET | sed 's/"//g' )
        RET=$( echo $RET | sed 's/\@/command-/g' )
        RET=$( echo $RET | sed 's/\^/control-/g' )
        RET=$( echo $RET | sed 's/\$/shift-/g' )
        RET=$( echo $RET | sed 's/\~/option-/g' )
        RET=$( echo $RET | ascii2uni -a U -q )
        echo $RET | tr ";" "\n "
    fi
}

i="NSGlobalDomain"
PRINT_DOMAIN $i

for i in `defaults domains | tr ',' '\n'`; do 
    PRINT_DOMAIN $i
done
 
