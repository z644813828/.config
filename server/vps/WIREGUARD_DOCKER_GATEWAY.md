# WireGuard Docker Gateway

Документация по текущей схеме доступа к домашнему серверу через VPS и Docker-контейнер.

## Схема

```text
Mac / iPhone
  -> WireGuard
  -> VPS <VPS_PUBLIC_IP>
  -> WireGuard
  -> Docker container vpn-gateway
  -> socat forwards
  -> Docker host services
```

## Узлы

- VPS: `<VPS_PUBLIC_IP>`
- VPS WireGuard IP: `10.80.0.1`
- Docker container: `vpn-gateway`
- Container WireGuard IP: `10.80.0.10`
- Mac WireGuard IP: `10.80.0.2`
- iPhone WireGuard IP: `10.80.0.3`
- Docker host from container: `172.17.0.1`
- Container Docker bridge IP now: `172.17.0.3`

`172.17.0.3` нужен только для allow-правил на сервисах хоста, потому что `socat` открывает новое TCP-соединение из контейнера к хосту.

## VPS

WireGuard server:

```text
/etc/wireguard/wg0.conf
```

Autostart:

```bash
systemctl enable wg-quick@wg0
systemctl status wg-quick@wg0
```

Client configs:

```text
/root/wireguard-clients/device1.conf
/root/wireguard-clients/iphone.conf
```

Show peers:

```bash
wg show wg0
```

## Container

Container name:

```text
vpn-gateway
```

Important files inside container:

```text
/etc/wireguard/wg0.conf
/usr/local/bin/wireguard-go
/usr/local/bin/start-vpn-gateway
/usr/local/bin/stop-vpn-gateway
/usr/local/bin/start-host-forwards
/usr/local/bin/check-vpn-gateway
```

The container uses `wireguard-go` because the Docker host kernel does not support kernel WireGuard in the container.

Check health:

```bash
docker exec vpn-gateway /usr/local/bin/check-vpn-gateway
```

Restart gateway manually:

```bash
docker exec vpn-gateway /usr/local/bin/start-vpn-gateway
```

## Forwarded Ports

Container forwards these ports from `10.80.0.10` to the Docker host:

```text
10.80.0.10:2222  -> 172.17.0.1:22
10.80.0.10:80    -> 172.17.0.1:80
10.80.0.10:443   -> 172.17.0.1:443
10.80.0.10:445   -> 172.17.0.1:445
10.80.0.10:548   -> 172.17.0.1:548
10.80.0.10:5000  -> 172.17.0.1:5000
10.80.0.10:8880  -> 172.17.0.1:8880
10.80.0.10:18790 -> 172.17.0.1:18790
10.80.0.10:2812  -> 172.17.0.1:2812
10.80.0.10:4000  -> 172.17.0.1:4000
10.80.0.10:9091  -> 172.17.0.1:9091
10.80.0.10:199   -> 172.17.0.1:199
10.80.0.10:8443  -> 192.168.2.1:8443
```

Access examples:

```text
ssh -p 2222 <user>@10.80.0.10
http://10.80.0.10
https://10.80.0.10
http://10.80.0.10:8880
https://10.80.0.10:199
https://10.80.0.10:8443
https://10.80.0.10:2812
smb://10.80.0.10
afp://10.80.0.10
```

## Host Allow Rules

Because traffic reaches host services from the container, host services see source IP:

```text
172.17.0.3
```

Use this in nginx/Monit allow rules while the container keeps this Docker IP.

Example nginx:

```nginx
allow 172.17.0.3;      # docker vpn-gateway
```

Example Monit:

```monit
allow 172.17.0.3
```

## Monitoring

Host Monit rule:

```text
/etc/monit/conf.d/vpn_gateway.conf
```

Host wrapper:

```text
/etc/monit/scripts/vpn_gateway.sh
```

Container check script:

```text
/usr/local/bin/check-vpn-gateway
```

The host wrapper runs:

```bash
docker exec vpn-gateway /usr/local/bin/check-vpn-gateway
```

This checks:

- container is running;
- `wg0` exists inside the container;
- WireGuard handshake is fresh;
- container can ping VPS WireGuard IP `10.80.0.1`;
- all forwarded ports are listening inside the container.

## Autostart

The container was recreated from a committed image with a startup command that runs:

```bash
service ssh start
/usr/local/bin/start-vpn-gateway
tail -f /dev/null
```

Verify after reboot:

```bash
docker ps --filter name=vpn-gateway
docker exec vpn-gateway /usr/local/bin/check-vpn-gateway
```

## Docker IP Stability

Current allow rules depend on:

```text
172.17.0.3
```

This usually survives `docker restart`, but can change after:

```bash
docker rm vpn-gateway
docker run ...
```

No need to change anything while the current container works. If the container is recreated later, either update nginx/Monit allow rules with the new Docker IP or move the container to a custom Docker network with a fixed IP.

## SSH Policy

SSH password login is disabled on:

- VPS `<VPS_PUBLIC_IP>`
- VPN container `vpn-gateway`

Effective expected settings:

```text
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin without-password
```
