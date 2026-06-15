# Docker Published Ports Firewall

Restricts selected Docker container TCP ports to trusted networks.

Docker published ports are DNATed before normal host `INPUT` filtering, so these rules live in the `DOCKER-USER` chain. The script resolves current container IPs with `docker inspect` and filters the post-DNAT container destination.

## Allowed Sources

```text
10.80.0.0/24
192.168.1.0/24
192.168.2.0/24
192.168.10.0/24
192.168.10.2/32
172.30.0.1/32
172.30.0.3/32
```

## Restricted Services

```text
openclaw:22
openclaw:18789
vpn-gateway:22
```

## Install

Run on the Docker host:

```bash
cd /path/to/server/docker/firewall
sudo install -m 0755 docker-published-ports-firewall.sh /usr/local/sbin/docker-published-ports-firewall.sh
sudo install -m 0644 docker-published-ports-firewall.service /etc/systemd/system/docker-published-ports-firewall.service
sudo systemctl daemon-reload
sudo systemctl enable --now docker-published-ports-firewall.service
```

## Verify

```bash
sudo iptables -S DOCKER-USER | grep managed-by-docker-published-ports-firewall
```

Connections to those Docker-published ports should work only from WireGuard and LAN networks.
