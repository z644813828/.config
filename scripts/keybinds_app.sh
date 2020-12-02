#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# print all binded keys
PRINT_DOMAIN(){
    RET=$( { defaults read $i NSUserKeyEquivalents; } 2>&1 )
    if [[ $RET != *"does not exist"* ]]; then
        printf "${GREEN}%s${NC}\n" "$i"
        RET=$( echo "$RET" | sed 's/\\U/u/g' )
        RET=$( echo "$RET" | sed 's/\\uf704/F1/g' )
        RET=$( echo "$RET" | sed 's/\\uf705/F2/g' )
        RET=$( echo "$RET" | sed 's/\\uf706/F3/g' )
        RET=$( echo "$RET" | sed 's/\\uf707/F4/g' )
        RET=$( echo "$RET" | sed 's/\\uf708/F5/g' )
        RET=$( echo "$RET" | sed 's/\\uf709/F6/g' )
        RET=$( echo "$RET" | sed 's/\\uf710/F7/g' )
        RET=$( echo "$RET" | sed 's/\\uf711/F8/g' )
        RET=$( echo "$RET" | sed 's/\\uf712/F9/g' )
        RET=$( echo "$RET" | sed 's/\\uf713/F10/g' )
        RET=$( echo "$RET" | sed 's/\\uf714/F11/g' )
        RET=$( echo "$RET" | sed 's/\\uf715/F12/g' )
        RET=$( echo "$RET" | sed 's/\\\\\\\\/\\/g' )
        RET=$( echo  $RET  | ascii2uni -a U -q )
        RET=$( echo "$RET" | sed 's/= "/-> " /g' )
        RET=$( echo "$RET" | sed 's/"//g' )
        RET=$( echo "$RET" | sed 's/{//g' )
        RET=$( echo "$RET" | sed 's/}//g' )
        RET=$( echo "$RET" | sed 's/\@/command + /g' )
        RET=$( echo "$RET" | sed 's/\^/control + /g' )
        RET=$( echo "$RET" | sed 's/\$/shift + /g' )
        RET=$( echo "$RET" | sed 's/\~/option + /g' )
        RET=$( echo "$RET" | sed 's/;/;\\t/g' )
        echo -e "\t$RET" | tr ";" "\n "
    fi
}


LOGO1(){
    echo
    printf "${RED}  ,-.                          ,-.      .   .                 \n /                    o       (   \`     |   |   o             \n | -. ,-. ;-. ,-. ;-. . ,-.    \`-.  ,-. |-  |-  . ;-. ,-: ,-. \n \\  | |-' | | |-' |   | |     .   ) |-' |   |   | | | | | \`-. \n  \`-' \`-' ' ' \`-' '   ' \`-'    \`-'  \`-' \`-' \`-' ' ' ' \`-| \`-' \n                                                      \`-'     \n ${NC}"
    echo
}

LOGO2(){
    echo
    printf "${RED} ,  ,             .                   ,--. .                   .       \n | /              |   o               |    |                   |       \n |<   ,-: ;-. ,-: |-. . ;-. ,-. ;-.   |-   | ,-. ;-.-. ,-. ;-. |-  ,-. \n | \\  | | |   | | | | | | | |-' |     |    | |-' | | | |-' | | |   \`-. \n '  \` \`-\` '   \`-\` \`-' ' ' ' \`-' '     \`--' ' \`-' ' ' ' \`-' ' ' \`-' \`-' \n ${NC}"
    echo
}


INIT(){
    K="$HOME/.config/karabiner/karabiner.json"
    FILE=$(cat $K | jq '.profiles[0].complex_modifications')
    rules_length=$(echo "$FILE" | jq '.rules | length')
}

GET_LINE(){
    DATA=$(echo "$FILE" | jq ".rules[$1]")
}
GET_MANIPULATORS_LENGTH(){
    j_max=$(echo "$DATA" | jq ".manipulators | length")
}

GET_DESCRIPTION(){
    description=$(echo "$DATA" | jq ".description")
    description=$(echo $description | sed 's/"//g' )
    printf "${GREEN}%s${NC}\n" "$description"
}

FILL_DATA(){
    f_key=$(  echo "$DATA" | jq ".manipulators[$1].from.key_code")
    f_mod_o=$(echo "$DATA" | jq ".manipulators[$1].from.modifiers.optional")
    f_mod_m=$(echo "$DATA" | jq ".manipulators[$1].from.modifiers.mandatory")
    t_key=$(  echo "$DATA" | jq ".manipulators[$1].to[0].key_code")
    t_mod=$(  echo "$DATA" | jq ".manipulators[$1].to[0].modifiers")
    t_cmd=$(  echo "$DATA" | jq ".manipulators[$1].to[0].shell_command")
}

SED(){
    f_mod_o=$(echo $f_mod_o | sed 's/\[//g' )
    f_mod_o=$(echo $f_mod_o | sed 's/\]//g' )
    f_mod_o=$(echo $f_mod_o | sed 's/, / + /g' )

    f_mod_m=$(echo $f_mod_m | sed 's/\[//g' )
    f_mod_m=$(echo $f_mod_m | sed 's/\]//g' )
    f_mod_m=$(echo $f_mod_m | sed 's/, / + /g' )

    t_mod=$(echo $t_mod | sed 's/\[//g' )
    t_mod=$(echo $t_mod | sed 's/\]//g' )
    t_mod=$(echo $t_mod | sed 's/, / + /g' )

    f_mod_o=$(echo $f_mod_o | sed 's/"//g' )
    f_mod_m=$(echo $f_mod_m | sed 's/"//g' )
    f_key=$(echo $f_key | sed 's/"//g' )
    t_key=$(echo $t_key | sed 's/"//g' )
    t_mod=$(echo $t_mod | sed 's/"//g' )
    t_cmd=$(echo $t_cmd | sed 's/"//g' )
}

TRUNC(){
    mlt=0
    mlt2=0
    if [[ "$f_mod_o" == "null" ]]; then f_mod_o=""; ((mlt+=1)); fi
    if [[ "$f_mod_m" == "null" ]]; then f_mod_m=""; ((mlt+=1)); fi
    if [[ "$t_key" == "null" ]]; then t_key=""; fi
    if [[ "$t_mod" == "null" ]]; then mlt2=1; t_mod=""; fi
    if [[ "$t_cmd" == "null" ]]; then t_cmd=""; fi
    if [[ "$mlt" == 2 ]]; then mlt=""; else mlt="+"; fi
    if [[ "$mlt2" == 1 ]]; then mlt2=""; else mlt2="+"; fi
}

ECHO(){
    echo -e '\t' $f_mod_o $f_mod_m $mlt $f_key '->' $t_mod $mlt2 $t_key $t_cmd
}


# Main() 

##############################################################################
# Print domains
##############################################################################

LOGO1
i="NSGlobalDomain"
PRINT_DOMAIN $i

for i in `defaults domains | tr ',' '\n'`; do 
    PRINT_DOMAIN $i
done

##############################################################################
# Print karabiner hotkeys
##############################################################################

LOGO2
INIT
for (( i = 0; i < $rules_length; i+=1 )); do
    echo
    GET_LINE $i
    GET_MANIPULATORS_LENGTH
    GET_DESCRIPTION $i
    for (( j = 0; j < $j_max; j+=1 )); do
        FILL_DATA $j
        SED
        TRUNC 
        ECHO
    done
done
