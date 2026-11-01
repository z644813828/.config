#!/bin/bash
set -euo pipefail

test -r /etc/monit-telegram.env
test -r /etc/apparmor.d/proxmox-monit-telegram
docker image inspect local/monit-telegram:migration >/dev/null
if docker container inspect monit-telegram >/dev/null 2>&1; then
    echo "STOP: monit-telegram already exists; inspect it before changing it"
    exit 1
fi

exec docker run -d \
    --name monit-telegram \
    --restart unless-stopped \
    --network host \
    --env-file /etc/monit-telegram.env \
    --mount type=volume,source=proxmox-monit-telegram-queue,target=/var/lib/monit-telegram \
    --read-only \
    --cap-drop ALL \
    --security-opt apparmor=proxmox-monit-telegram \
    --security-opt no-new-privileges:true \
    --log-opt max-size=5m \
    --log-opt max-file=2 \
    local/monit-telegram:migration
