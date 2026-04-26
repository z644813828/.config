# Задача для другого Codex: поднять такую же связку на новом сервере

Нужно воспроизвести текущую схему: 3x-ui, MTProto через `mtg`, отдельный MTProto web UI, мониторинг трафика по пользователям.

## Переменные

Перед началом замени значения:

```bash
NEW_HOST="root@NEW_SERVER_IP"
SERVER_IP="NEW_SERVER_IP"
SSH_KEY="/path/to/key"
PANEL_USER="same-as-3x-ui-login"
PANEL_PASS="same-as-3x-ui-password"
THREEXUI_PORT="29710"
THREEXUI_PATH="/your-panel-path/"
MTPROTO_WEB_PORT="8448"
FIRST_MTPROTO_PORT="8443"
```

## 1. Подготовить сервер

```bash
ssh -i "$SSH_KEY" "$NEW_HOST"
apt update
apt install -y curl wget git ca-certificates unzip tar jq iptables iproute2 php-cli openssl socat
```

Открыть в firewall/security group:

- SSH: `22/tcp`
- 3x-ui panel port, например `29710/tcp`
- MTProto web UI HTTPS, например `8448/tcp`
- MTProto proxy ports, например `8443-8499/tcp`

Сразу после первичной настройки сервера рекомендуется:

```bash
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d%H%M%S)
printf '\n/swapfile none swap sw 0 0\n' >> /etc/fstab
findmnt --verify
```

И ограничить `journald`:

```bash
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/limits.conf <<'EOF'
[Journal]
SystemMaxUse=50M
RuntimeMaxUse=30M
MaxRetentionSec=7day
EOF

systemctl restart systemd-journald
journalctl --vacuum-size=50M
```

## 2. Установить 3x-ui

Использовать официальный installer проекта MHSanaei/3x-ui:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh)
```

После установки настроить:

- login/password: `PANEL_USER` / `PANEL_PASS`;
- panel port: `THREEXUI_PORT`;
- panel path: `THREEXUI_PATH`;
- HTTPS-сертификат для панели, если нужен.

Проверить:

```bash
systemctl status x-ui --no-pager
x-ui
```

Важно:

- настройки панели 3x-ui лежат в `/etc/x-ui/x-ui.db`;
- `/usr/local/x-ui/bin/config.json` - это runtime-конфиг Xray, а не главная база настроек панели.

## 3. Установить mtg

Скачать релиз `9seconds/mtg` под архитектуру сервера или собрать из исходников. В итоге бинарник должен быть здесь:

```bash
/usr/local/bin/mtg
```

Проверка:

```bash
chmod +x /usr/local/bin/mtg
/usr/local/bin/mtg --help
```

## 4. Создать MTProto-пользователя

Пример для пользователя `Dmitriy` на порту `8443`:

```bash
SECRET="$(/usr/local/bin/mtg generate-secret tls -c google.com)"
cat > /etc/mtg-Dmitriy.toml <<EOF
secret = "$SECRET"
bind-to = "0.0.0.0:8443"
EOF

cat > /etc/systemd/system/mtg-Dmitriy.service <<'EOF'
[Unit]
Description=MTProto proxy Dmitriy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mtg run /etc/mtg-Dmitriy.toml
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now mtg-Dmitriy.service
/usr/local/bin/mtg access /etc/mtg-Dmitriy.toml
```

Для следующих пользователей использовать соседние порты: `8444`, `8445`, `8446` и т.д. Каждый пользователь - отдельный файл `/etc/mtg-<User>.toml` и отдельный сервис `mtg-<User>.service`.

## 5. Поставить мониторинг трафика

Скопировать из этого проекта:

- `mtproto/mtproto-traffic.sh` -> `/usr/local/bin/mtproto-traffic`
- `mtproto/mtproto-traffic-sync.service` -> `/etc/systemd/system/mtproto-traffic-sync.service`
- `mtproto/mtproto-traffic-collect.service` -> `/etc/systemd/system/mtproto-traffic-collect.service`
- `mtproto/mtproto-traffic-collect.timer` -> `/etc/systemd/system/mtproto-traffic-collect.timer`

Команды на сервере:

```bash
chmod +x /usr/local/bin/mtproto-traffic
mkdir -p /var/lib/mtproto-traffic
systemctl daemon-reload
systemctl enable --now mtproto-traffic-sync.service
systemctl enable --now mtproto-traffic-collect.timer
/usr/local/bin/mtproto-traffic sync
/usr/local/bin/mtproto-traffic collect
/usr/local/bin/mtproto-traffic report
```

Если переносится сервер с уже накопленной статистикой, отдельно решить, переносить ли `/var/lib/mtproto-traffic/*.tsv`.

## 6. Развернуть MTProto web UI

Скопировать:

```bash
mkdir -p /opt/mtproto-web
cp server-mtproto-admin.php /opt/mtproto-web/index.php
```

В `/opt/mtproto-web/index.php` заменить в начале файла:

```php
$authUser = 'PANEL_USER';
$authPass = 'PANEL_PASS';
$serverHost = 'SERVER_IP';
```

Создать сервис PHP:

```bash
cat > /etc/systemd/system/mtproto-web.service <<'EOF'
[Unit]
Description=MTProto web admin
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/mtproto-web
ExecStart=/usr/bin/php -S 127.0.0.1:8088 index.php
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

Создать HTTPS-wrapper через `socat`. Ниже пример с сертификатами `/root/cert/ip/fullchain.pem` и `/root/cert/ip/privkey.pem`; путь адаптировать под новый сервер.

```bash
cat > /etc/systemd/system/mtproto-web-tls.service <<EOF
[Unit]
Description=MTProto web admin TLS wrapper
After=network-online.target mtproto-web.service
Wants=network-online.target
Requires=mtproto-web.service

[Service]
Type=simple
ExecStart=/usr/bin/socat OPENSSL-LISTEN:${MTPROTO_WEB_PORT},reuseaddr,fork,cert=/root/cert/ip/fullchain.pem,key=/root/cert/ip/privkey.pem,verify=0 TCP:127.0.0.1:8088
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF
```

Запустить:

```bash
systemctl daemon-reload
systemctl enable --now mtproto-web.service
systemctl enable --now mtproto-web-tls.service
```

Чтобы MTProto UI автоматически подхватывал новый сертификат после обновления cert/key, создать еще watcher:

```bash
cat > /etc/systemd/system/mtproto-web-tls-reload.service <<'EOF'
[Unit]
Description=Restart MTProto Admin Web TLS when certificate files change

[Service]
Type=oneshot
ExecStart=/bin/systemctl restart mtproto-web-tls.service
EOF

cat > /etc/systemd/system/mtproto-web-tls-reload.path <<'EOF'
[Unit]
Description=Watch MTProto Admin TLS certificate files

[Path]
PathChanged=/root/cert/ip/fullchain.pem
PathChanged=/root/cert/ip/privkey.pem
PathModified=/root/cert/ip/fullchain.pem
PathModified=/root/cert/ip/privkey.pem
Unit=mtproto-web-tls-reload.service

[Install]
WantedBy=paths.target
EOF

systemctl daemon-reload
systemctl enable --now mtproto-web-tls-reload.path
```

Проверить:

```bash
systemctl status mtproto-web.service --no-pager
systemctl status mtproto-web-tls.service --no-pager
systemctl status mtproto-web-tls-reload.path --no-pager
curl -k "https://${SERVER_IP}:${MTPROTO_WEB_PORT}/" -I
```

## 7. Финальная проверка

```bash
systemctl list-units 'mtg-*' --no-pager
/usr/local/bin/mtproto-traffic sync
/usr/local/bin/mtproto-traffic report
/usr/local/bin/mtproto-traffic report-month
ss -ltnp | grep -E '8443|8448|29710'
```

Открыть:

- 3x-ui: `https://SERVER_IP:THREEXUI_PORT/THREEXUI_PATH`
- MTProto UI: `https://SERVER_IP:MTPROTO_WEB_PORT/`

## 8. Важные детали текущей реализации

- Веб UI не использует базу данных: все берется из `/etc/mtg-*.toml`, systemd, `ss` и `/usr/local/bin/mtproto-traffic`.
- Онлайн определяется по `ESTABLISHED` TCP-соединениям на порт пользователя.
- Тумблер в UI включает/выключает systemd-сервис пользователя, но не удаляет конфиг.
- После любых изменений пользователей нужно запускать `/usr/local/bin/mtproto-traffic sync`.
- `collect` должен работать регулярно через timer, иначе трафик будет обновляться только при открытии UI или ручных командах.
- MTProto UI использует отдельный `socat` TLS-wrapper, и без `mtproto-web-tls-reload.path` новый сертификат сам не подхватится.
- В текущем UI уже есть compact mode, автообновление без полной перезагрузки страницы и встроенный health-check блок.
