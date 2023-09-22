#!/bin/bash

MAIN_PC_IP="192.168.2.2"
ARDUINO_IP="192.168.2.250"

MONIT_IGNORE_REGEX="Monit|Service Name|Status ok|Running|Accessible|Online with all services"

! ping -c 1 $MAIN_PC_IP &> /dev/null
main_pc=$?
mosquitto_pub -h localhost -t "led/enabled" -m "$main_pc"

! ping -c 1 $ARDUINO_IP &> /dev/null
arduino=$?

monit=$(monit summary | grep -v -E "$MONIT_IGNORE_REGEX" | awk '{ print $1 }')
monit=$(echo $monit|tr -d '\n')
mosquitto_pub -h localhost -t "monit/text" -m "$monit"


echo "
{
    \"pc\": $main_pc,
    \"arduino\": $arduino,
    \"summary\": \"$monit\"
}" > /var/log/arduino.log

if [ $arduino ]; then
    exit 1
fi

exit 0
