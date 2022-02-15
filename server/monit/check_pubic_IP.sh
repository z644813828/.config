#!/bin/bash
IP_ADDR=$(curl -s http://myip.enix.org/REMOTE_ADDR)
file="/var/log/public_IP.log"

if [[ -z "$IP_ADDR" ]]; then
    exit 1
fi
INP=($(tail -n 1 $file))
LAST_IP=${INP[1]}
DATE=$(date +"%D-%T")
if [[ $LAST_IP != $IP_ADDR ]]; then
    echo "$DATE $IP_ADDR" >> $file
fi
exit 0;

