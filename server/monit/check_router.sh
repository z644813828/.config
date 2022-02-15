#!/bin/bash

ret=0

echo "_"
echo " "

ports=(128 8443)
for i in "${ports[@]}"
do
    nc -z -v -w5 192.168.2.1 $i 2>&1
    [ $? -eq 0 ] || ret=1
done

exit $ret;
