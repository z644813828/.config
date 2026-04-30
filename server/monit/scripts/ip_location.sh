#!/usr/bin/env bash

function process_line()
{
    local line="$1"

    DATE="$(echo $line | grep -m1 -oP '.*SERVER')"
    IP="$(echo $line | grep -m1 -oP '(?:\d{1,3}\.){3}\d{1,3}')"

    if [[ $IP != "" ]]; then
        IP="$(echo ${IP:0:15})"
        if [[ $IP != $IP_LAST ]]; then
            Geo="$(geoiplookup $IP -f /usr/share/GeoIP/GeoIPCity.dat)"
            IP_LAST=$IP
            FORMATTED_MSG=$(printf "%15s %15s %s\n" "$DATE" "$IP" "${Geo:27:100}")
            echo $FORMATTED_MSG
            echo $FORMATTED_MSG >> /var/log/auth2.log
        fi
    fi
}

line=$MONIT_DESCRIPTION
IP_LAST=""

if [[ -z "$line" ]]; then
    tail -n 100 /var/log/auth.log | grep -v -f /etc/monit/whitelist_ips.regex | while read line
    do
        process_line "$line"
    done
else
    echo $line >> /var/log/auth2.log
    process_line "$line"
fi

