#!/bin/bash

if openssl x509 -checkend 86400 -noout -in /var/certs/monit.pem
then
    exit 0;
else
    echo "_"
    echo " "
    echo "Renewing certificates"
    systemctl stop nginx.service

    certbot renew --force-renewal
    cd /etc/letsencrypt/live/PATH_TO_DDNS
    cat fullchain.pem privkey.pem > monit.pem
    chmod 700 monit.pem
    mv -f monit.pem /var/certs/
    cp {fullchain.pem,privkey.pem} /sharedfolders/Software/_Software/_RT-AC68U/certs/

    systemctl start nginx.service
    systemctl restart monit.service
    exit 1;
fi
