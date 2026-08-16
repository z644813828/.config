# rclone-cloud

Контейнер для запуска `rclone` с доступом к локальным backup-данным и SSH через
`vpn-gateway`.

При сборке загружается актуальный стабильный бинарник rclone с официального
`downloads.rclone.org`; Debian-пакет rclone не используется.

## Данные

- `/backup` -> `/srv/dev-disk-by-label-Backups` на Docker-хосте, read-only.
- `/root/.config/rclone` -> `/root/.backup-secrets/rclone` на Docker-хосте.
- `/workspace` -> `./workspace` рядом с compose-файлом.

## SSH

Контейнер имеет фиксированный адрес `172.30.0.4` в `infra_net`. SSH не
публикуется на Docker-хосте и принимает только ключи из `authorized_keys` в
`/root/.backup-secrets/rclone/authorized_keys` на Docker-хосте. Этот файл не
хранится в image или Git. Изменения ключей применяются после пересоздания
контейнера.

Добавить в `~/.ssh/config` клиента:

```sshconfig
Host server_rclone_cloud
    User root
    HostName 172.30.0.4
    Port 22
    ProxyJump server_vpn_gateway
```

LAN access through the Docker published port:

```sshconfig
Host server_rclone_cloud_lan
    User root
    HostName 192.168.2.254
    Port 2024
```

## Запуск на Docker-хосте

```bash
cd /docker/compose/rclone-cloud
docker-compose up -d --build
sudo /usr/local/sbin/docker-published-ports-firewall.sh
```

## Проверка

```bash
docker exec rclone-cloud rclone version
docker exec rclone-cloud rclone config show
ssh server_rclone_cloud
ssh server_rclone_cloud_lan
```

## Production backup

После того как `/backup` заменён на непустой read-only mount:

```bash
docker exec rclone-cloud /workspace/scripts/backup-to-gdrive.sh
```

Recovery-инструкция находится в `/workspace/docs/RESTORE.md`.
