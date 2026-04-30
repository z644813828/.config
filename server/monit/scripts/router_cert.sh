#!/bin/bash

set -u

ROUTER_HOST="192.168.2.1"
ROUTER_PORT="8443"
CERT_NAME="DDNS_NAME"
LOCAL_CERT="/etc/letsencrypt/live/${CERT_NAME}/cert.pem"

echo "_"
echo " "

if [ ! -r "$LOCAL_CERT" ]; then
    echo "Local certificate is not readable: $LOCAL_CERT"
    exit 2
fi

local_fingerprint=$(openssl x509 -in "$LOCAL_CERT" -noout -fingerprint -sha256 2>/dev/null)
if [ -z "$local_fingerprint" ]; then
    echo "Failed to read local certificate fingerprint: $LOCAL_CERT"
    exit 2
fi

remote_cert=$(
    timeout 15 openssl s_client \
        -connect "${ROUTER_HOST}:${ROUTER_PORT}" \
        -servername "$CERT_NAME" \
        -showcerts </dev/null 2>/dev/null |
    openssl x509 -noout -fingerprint -sha256 2>/dev/null
)

if [ -z "$remote_cert" ]; then
    echo "Failed to read router certificate from ${ROUTER_HOST}:${ROUTER_PORT}"
    exit 3
fi

echo "Local certificate:"
openssl x509 -in "$LOCAL_CERT" -noout -subject -issuer -dates -serial

echo " "
echo "Router certificate:"
timeout 15 openssl s_client \
    -connect "${ROUTER_HOST}:${ROUTER_PORT}" \
    -servername "$CERT_NAME" \
    -showcerts </dev/null 2>/dev/null |
openssl x509 -noout -subject -issuer -dates -serial 2>/dev/null

if [ "$local_fingerprint" != "$remote_cert" ]; then
    echo " "
    echo "Router certificate does not match the current Let's Encrypt certificate"
    echo "Local:  $local_fingerprint"
    echo "Router: $remote_cert"
    exit 1
fi

exit 0
