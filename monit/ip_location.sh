#!/bin/bash
DESCRIPTION="Apr  1 21:46:52 SERVER sshd[2247]: Accepted publickey for dmitriy from 192.168.2.1 port 64017 ssh2: RSA SHA256:ephPhjIDft/9YB5nlibWb/8WQOD2FD  3pnRqA0nZaSrY"
# DESCRIPTION=$1
IP="$(echo $DESCRIPTION | grep -oP '(?:\d{1,3}\.){3}\d{1,3}')"
echo IP=$IP
if [[ $IP = "192.168.2.1" ]]; then
    echo Connected via LocalHost
else
    Geo="$(geoiplookup $IP -f /usr/share/GeoIP/GeoIPCity.dat)"
    echo $Geo
fi
