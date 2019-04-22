#!/bin/bash
# ./ip_location.sh | vim -
cat /var/log/auth.log | while read line
do
    IP="$(echo $line | grep -m1 -oP '(?:\d{1,3}\.){3}\d{1,3}')"
    if [[ $IP != "" ]]; then
        IP="$(echo ${IP:0:15})"
        if [[ $IP != $IP_LAST ]]; then
            Geo="$(geoiplookup $IP -f /usr/share/GeoIP/GeoIPCity.dat)"
            IP_LAST=$IP
            if (!(echo $Geo | grep --quiet Address) && !(echo $Geo | grep --quiet resolve) && !(echo $Geo | grep --quiet Moscow)); then
                # if !(echo $Geo | grep --quiet Moscow); then
                    printf "%15s %s\n" "$IP" "${Geo:27:100}"
                    IP_LAST=$IP
                # fi
            fi
        fi
    fi
done

DESCRIPTION=$1
IP="$(echo $DESCRIPTION | grep -oP '(?:\d{1,3}\.){3}\d{1,3}')"
echo IP=$IP
if [[ $IP = "192.168.2.1" ]]; then
    echo Connected via LocalHost
else
    Geo="$(geoiplookup $IP -f /usr/share/GeoIP/GeoIPCity.dat)"
    echo $Geo
fi
