#!/bin/bash

ret=0

DDNS=""

echo "_"
echo " "

ports=(128 8443)
for i in "${ports[@]}"
do
    nc -z -v -w5 192.168.2.1 $i 2>&1
    [ $? -eq 0 ] || ret=1
done

ports=()
ports+=(443)	#OMV main page
ports+=(9091)	#Transmission
ports+=(199)	#NetData
ports+=(4000)	#Moniit
ports+=(8880)	#FileBrowser
ports+=(4041)	#Ngrok

for i in "${ports[@]}"
do
    nc -z -v -w5 $DDNS $i 2>&1
    [ $? -eq 0 ] || ret=1
done

exit $ret;
