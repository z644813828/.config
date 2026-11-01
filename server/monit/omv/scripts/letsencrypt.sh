#!/bin/bash
set -euo pipefail

# Set the deployed certificate path locally; do not commit private hostnames.
CERT="${CERT:-/etc/letsencrypt/live/server.example.invalid/fullchain.pem}"
WARN_SECONDS=$((14 * 24 * 60 * 60))

if ! openssl x509 -in "$CERT" -noout -enddate; then
    echo "ERROR: cannot read certificate"
    exit 2
fi

if ! openssl x509 -in "$CERT" -noout -checkend "$WARN_SECONDS"; then
    echo "WARNING: certificate expires within 14 days or has expired"
    exit 2
fi

echo "OK: certificate is valid for more than 14 days"
