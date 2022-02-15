#!/bin/bash

#primary wired ethernet channel
GW1_NAME="wlp2s0"
GW1_ADDR="192.168.2.131"
GW1_DNS="192.168.2.1"

#reserved wifi channel
GW2_NAME="enp0s29u1u2"
GW2_ADDR="192.168.42.8"
GW2_DNS="192.168.42.129"

HOST="google.com"
DATE_FILE="/tmp/switch_provider"
RESERVE_CHANNEL_CHECK_CYCLE="30"

# GW1_ADDR=$(ip route | grep -v default| grep $GW1_NAME | grep src | awk -F " " '{print $9}')
# GW1_DNS=$(ip route |  grep -m 1 $GW1_NAME | awk -F " " '{print $3}')

echo " "

# get currently using gateway
gateway=$(ip route get 8.8.8.8 | awk -F " " '{print $5}')

ADD_RESERVE_CHANNEL(){
    ip route add default via ${GW2_DNS} proto static metric 100
}

DEL_RESERVE_CHANNEL(){
    ip route delete default via ${GW2_DNS}
}

# ping via primary channel
ping -q -c 1 -I ${GW1_NAME} ${HOST} > /dev/null 2>&1
if [ $? -ne 0 ]; then # ping failed
    if [ $gateway == $GW1_NAME ]; then #primary wired ethernet channel
        ADD_RESERVE_CHANNEL
        echo "Switched to reserved ethernet channel"
        exit 1
    else #reserved wifi channel
        echo "reserved channel active"
        exit 0
    fi
else # ping succeeded
    if [ $gateway == $GW1_NAME ]; then #primary wired ethernet channel
        # ping via reserved channel
        last_date=$(cat $DATE_FILE)
        if [ $last_date == RESERVE_CHANNEL_CHECK_CYCLE ]; then
            echo "0" > $DATE_FILE
            ADD_RESERVE_CHANNEL
            ping -q -c 1 -I ${GW2_NAME} ${HOST} > /dev/null 2>&1
            res=$?
            DEL_RESERVE_CHANNEL
            if [ $res -ne 0 ]; then
                echo "Reserved channel " $GW2_NAME " is not working!"
                exit 1
            else
                exit 0
            fi
        else
            last_date=$(($last_date+1))
            echo $last_date > $DATE_FILE
            exit 0
        fi
    else #reserved wifi channel
        DEL_RESERVE_CHANNEL
        echo "Switched to primary ethernet channel"
        exit 1
    fi
fi
