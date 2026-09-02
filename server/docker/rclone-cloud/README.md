# rclone-cloud

Контейнер для запуска `rclone` с доступом к локальным backup-данным и SSH через
`vpn-gateway`.

При сборке загружается актуальный стабильный бинарник rclone с официального
`downloads.rclone.org`; Debian-пакет rclone не используется.

## Данные

- `/backup` -> `/srv/dev-disk-by-label-Backups` (`/dev/sdf1`) на Docker-хосте, read-only.
- `/root/.config/rclone` -> `/root/.backup-secrets/rclone` на Docker-хосте.
  Здесь лежит `rclone.conf` (client_id/secret + OAuth-токен) — **в image и Git не попадает**.
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
docker exec rclone-cloud rclone lsd gdrive_backups:
docker exec rclone-cloud rclone about gdrive_backups:
docker exec rclone-cloud bash /workspace/scripts/last-gdrive-backup.sh
ssh server_rclone_cloud
ssh server_rclone_cloud_lan
```

## Google Drive: remote и OAuth

Remote `gdrive_backups`, scope `drive.file` (видит только файлы, созданные rclone),
свой client_id из Google Cloud Console.

- Google-аккаунт: `<GOOGLE_ACCOUNT>`
- Проект в Cloud Console: `<GCP_PROJECT_NAME>`
- OAuth consent screen: App name `rclone backup`, Authorized domain `<DDNS_ROOT_DOMAIN>`,
  Homepage URL и Privacy policy URL: `https://<DDNS_HOST>/rclone-privacy.html`
- Publishing status: **Production** (переведено `<DATE>`). Верификация Google не
  отправлялась и не нужна: `drive.file` — нечувствительный scope.

### Почему Production

В статусе **Testing** refresh token живёт 7 дней, после чего бэкап молча ломается.
В **Production** токен бессрочный, пока не отозван вручную
(myaccount.google.com/permissions). Личный домен и верификация для этого не нужны.
Если когда-нибудь понадобится sensitive/restricted scope (например полный `drive`),
верификация уже потребуется.

### Страница для Branding

Google требует Homepage/Privacy URL по HTTPS — подходит любая статическая страница.
Она лежит на OMV-сервере (корень nginx `/var/www/openmediavault`), способ, который
OMV не перезаписывает:

```
/var/www/static/rclone-privacy.html
/etc/nginx/openmediavault-webgui.d/static.conf:
    location = /rclone-privacy.html { root /var/www/static; }
nginx -t && systemctl reload nginx
```

Если консоль потребует подтверждённый домен: в Search Console добавить ресурс
«префикс URL» `https://<DDNS_HOST>/` и подтвердить HTML-файлом
(права на корневой домен не нужны), либо разместить страницу на бесплатном Google Sites.

### Переавторизация

Нужна только если токен отозван или удалён `rclone.conf`.

Терминал 1 (Mac):

```bash
ssh -tt server_rclone_cloud_lan 'rclone config reconnect gdrive_backups:'
```

Ответы: Use web browser? → **y**; Shared Drive? → **n**. Rclone напечатает
`http://127.0.0.1:53682/auth?state=...`

Терминал 2 (Mac):

```bash
ssh -N -L 53682:127.0.0.1:53682 server_rclone_cloud_lan
```

Открыть URL в браузере → выбрать аккаунт → «Google hasn't verified this app» →
Advanced → Go to → Allow. После «Success!» reconnect в терминале 1 завершится,
туннель закрыть Ctrl+C. Затем проверить `rclone lsd gdrive_backups:` и
`backup-to-gdrive.sh` с `--dry-run`.

Запасной вариант без своего client_id: оставить client_id/secret пустыми —
rclone использует встроенный, но с общей квотой запросов.

## Production backup

После того как `/backup` заменён на непустой read-only mount:

```bash
docker exec rclone-cloud bash /workspace/scripts/backup-to-gdrive.sh
```

После успешного `rclone copy` скрипт обновляет plaintext-файл
`gdrive_backups:rclone/date.txt` с временем MSK (`+03:00`). Он расположен в видимой папке
`rclone` на Google Drive и не содержит имён или структуры бэкапа.

Прочитать время последнего успешного cloud-бэкапа:

```bash
docker exec rclone-cloud bash /workspace/scripts/last-gdrive-backup.sh
```

`/workspace` монтируется с `noexec`, поэтому cron должен запускать скрипт через
`bash`:

```cron
0 3 * * * /usr/bin/docker exec rclone-cloud /bin/bash /workspace/scripts/backup-to-gdrive.sh >> /var/log/rclone-cloud.log 2>&1
```

Monit-проверка находится в `server/monit/conf.d/rclone_cloud_backup.conf` и
считает бэкап устаревшим через 36 часов.

Recovery-инструкция находится в `/workspace/docs/RESTORE.md`.
