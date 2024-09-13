#!/bin/bash

sleep 60 # limit of 50k requests per month (30s daemon + 60s sleep)

DATA=$(curl -s ipinfo.io?token=MY_TOKEN)
IP_ADDR=$(echo $DATA | jq -r '.ip')
ISP=$(echo $DATA | jq -r '.org')

file="/var/log/public_IP.log"

if [[ -z "$IP_ADDR" ]]; then
    echo "Can't get public IP"
    echo $DATA
    exit 1
fi

INP=($(tail -n 1 $file))
LAST_IP=${INP[1]}
DATE=$(date +"%D-%T")

echo $ISP $IP_ADDR

if [[ $LAST_IP != $IP_ADDR ]]; then
    echo "$DATE $IP_ADDR" >> $file
    exit 1
fi
exit 0
