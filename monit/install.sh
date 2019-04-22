#!/bin/bash
sed -i'' -e 's/my_gmail/my_gmail/g' *
sed -i'' -e 's/server_gmail/server_gmail/g' *
sed -i'' -e 's/monit_pass/monit_pass/g' *

cp -r monitrc whitelist_ips.regex switch.sh /etc/monit/
cp -r *.conf /etc/monit/conf.d/
cp monit.cnf /var/certs/
cp jail.conf /etc/fail2ban/

cd /var/certs 
openssl req -new -x509 -nodes -config ./monit.cnf -out /var/certs/monit.pem -keyout /var/certs/monit.pem
chmod 700 /var/certs/monit.pem

echo > /var/log/server2.log
