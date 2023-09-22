#!/bin/bash
# DESCRIPTION="Apr  1 21:46:52 SERVER sshd[2247]: Accepted publickey for dmitriy from 192.168.2.1 port 64017 ssh2: RSA SHA256:ephPhjIDft/9YB5nlibWb/8WQOD2FD3pnRqA0nZaSrY"
# DESCRIPTION=$1
# IP="$(echo $DESCRIPTION | grep -oP '(?:\d{1,3}\.){3}\d{1,3}')"
# IP_LAST=""
# tail -n 100 /var/log/auth.log | while read line
cat /var/log/auth.log | while read line
do
    DATE="$(echo $line | grep -m1 -oP '.*d')"
    IP="$(echo $line | grep -m1 -oP '(?:\d{1,3}\.){3}\d{1,3}')"
    if [[ $IP != "" ]]; then
        IP="$(echo ${IP:0:15})"
        if [[ $IP != $IP_LAST ]]; then
            Geo="$(geoiplookup $IP -f /usr/share/GeoIP/GeoIPCity.dat)"
            IP_LAST=$IP
            if (!(echo $Geo | grep --quiet Address) && !(echo $Geo | grep --quiet resolve) && !(echo $Geo | grep --quiet Moscow)); then
            # if !(echo $Geo | grep --quiet Moscow); then
                printf "%15s %15s %s\n" "$DATE" "$IP" "${Geo:27:100}"
                IP_LAST=$IP
            fi
            fi
        fi
    # fi
done

