#!/bin/bash

if openssl x509 -checkend 86400 -noout -in /var/certs/monit.pem
then
    exit 0;
else
    echo "_"
    echo " "
    echo "Renewing certificates"
    systemctl stop nginx.service

    cert_log=$(certbot renew --force-renewal)
    
    if [ $? -ne 0 ]; then
        systemctl start nginx.service
        echo $cert_log
        sleep 1000 # limit of 5 failures per account, per hostname, per hour
        exit 2
    fi

    cd /etc/letsencrypt/live/z644813828.asuscomm.com/
    cat fullchain.pem privkey.pem > monit.pem
    chmod 700 monit.pem
    mv -f monit.pem /var/certs/
    cp {cert.pem,privkey.pem} /sharedfolders/Software/_Software/_RT-AC68U/certs/

    systemctl start nginx.service
    systemctl restart monit.service
    exit 1;
fi
