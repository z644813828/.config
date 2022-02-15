#!/bin/bash
# {{{ monit jails & conf
sed -i'' -e 's/my_gmail/my_gmail/g' *
sed -i'' -e 's/server_gmail/server_gmail/g' *
sed -i'' -e 's/monit_pass/monit_pass/g' *

cp -r monitrc whitelist_ips.regex *.sh /etc/monit/
cp -r *.conf /etc/monit/conf.d/
cp jail.conf /etc/fail2ban/

echo > /var/log/server2.log
# }}}

# {{{ ssl redirection for https
cp ssl_redirect transmission

sed -i'' -e 's/SERVER_NAME/transmission/g' ./transmission
sed -i'' -e 's/ACCESS_LOG/transmission/g' ./transmission
sed -i'' -e 's/SSL_PORT/9091/g' ./transmission
sed -i'' -e 's/HTTP_PORT/9092/g' ./transmission
cp transmission /etc/nginx/sites-enabled/

cp ssl_redirect netdata
sed -i'' -e 's/SERVER_NAME/netdata/g' ./netdata
sed -i'' -e 's/ACCESS_LOG/netdata/g' ./netdata
sed -i'' -e 's/SSL_PORT/199/g' ./netdata
sed -i'' -e 's/HTTP_PORT/19999/g' ./netdata
cp netdata /etc/nginx/sites-enabled/

rm -rf transmission netdata
# }}}

# {{{ generate certificates
openssl req -new -x509 -nodes -days 313 -config /var/certs/server.cnf -out /var/certs/server.pem -keyout /var/certs/server.pem
chmod 600 /var/certs/server.pem
# }}}

# {{{ restart srevices
systemctl restart monit.service
systemctl restart fail2ban.service
systemctl restart transmission-daemon.service
systemctl restart nginx.service
systemctl restart netdata.service
# }}}
