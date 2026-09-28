# OpenClaw

Короткая документация по текущей установке OpenClaw в Docker-контейнере.

## Compose для миграции

`docker-compose.yml` предназначен для Docker Compose v2 на новом хосте.
По умолчанию используется образ `openclaw:migration`, импортированный из
`openclaw/rootfs.tar.gz` миграционного комплекта. Для другого подготовленного
образа задайте `OPENCLAW_IMAGE`. Это не сборка OpenClaw с нуля.

До запуска восстановите `/root/.openclaw` и mounts из комплекта, сравните
настройки с `inventory/openclaw.json`. В compose нет предположительных volumes:
если они есть в сохранённом inspect, добавьте реальные mounts до запуска.
Сеть `infra_net` должна существовать с подсетью `172.30.0.0/24`.

```bash
docker compose config --quiet
docker compose up -d
docker compose logs --tail=50
```

Старый контейнер должен быть выключен: два экземпляра не должны одновременно
получать сообщения одного Telegram-бота. Токен читается внутри контейнера из
сохранённого конфига. Gateway работает на переднем плане с логами Docker;
его завершение приводит к завершению контейнера и применению restart policy.
Публикация портов требует прежних ограничений Docker firewall.

## Что поднято

- Docker image был зафиксирован после настройки как `openclaw-debian11-codex-telegram`.
- Контейнер называется `openclaw`.
- Внутри контейнера:
  - Debian 11;
  - Node.js `v24.15.0`;
  - npm `11.12.1`;
  - OpenClaw `2026.9.2`;
  - Codex CLI `0.153.4`;
  - `bubblewrap`;
  - Telegram channel.
- OpenClaw Gateway слушает внутри контейнера:
  - `0.0.0.0:18789`;
  - auth mode: `token`;
  - default model: `openai/gpt-5.6-sol`.
- Docker ports:
  - host `2022` -> container `22` for SSH;
  - host `18789` -> container `18789` for OpenClaw Gateway HTTP/WebSocket.
- Runtime safety:
  - run with `--init`;
  - run with `--pids-limit 256`.
- HTTPS снаружи сделан через nginx на хосте:
  - external HTTPS port: `18790`;
  - proxy target: `http://127.0.0.1:18789/`.
- Telegram bot подключен и paired с нужным Telegram user. Конкретный Telegram user ID не хранить в репозитории.

## Секреты

Секреты не хранить в этом каталоге.

Текущие секреты находятся только на сервере/в контейнере:

- OpenClaw gateway token:
  - `/root/.openclaw/openclaw.json`
  - `/root/.openclaw/gateway.token`
- OpenAI/Codex OAuth profiles:
  - `/root/.openclaw/state/openclaw.sqlite`
- Telegram bot token:
  - внутри OpenClaw config `/root/.openclaw/openclaw.json`

## Основные URL

OpenClaw UI:

```text
https://<DOMAIN>:18790/
```

WebSocket URL для Control UI:

```text
wss://<DOMAIN>:18790/
```

## Docker Firewall

Docker-published ports must be restricted on the Docker host through `DOCKER-USER`.

Shared firewall config:

```text
server/docker/firewall/
```

Restricted OpenClaw Docker ports:

```text
2022   SSH
18789  OpenClaw Gateway direct port
```

Allowed source networks:

```text
10.80.0.0/24
192.168.1.0/24
192.168.2.0/24
192.168.10.0/24
172.30.0.3/32
```

Install/update on the Docker host:

```bash
cd /path/to/server/docker/firewall
sudo install -m 0755 docker-published-ports-firewall.sh /usr/local/sbin/docker-published-ports-firewall.sh
sudo install -m 0644 docker-published-ports-firewall.service /etc/systemd/system/docker-published-ports-firewall.service
sudo systemctl daemon-reload
sudo systemctl enable --now docker-published-ports-firewall.service
```

## Проверка

```bash
docker ps --filter name=openclaw
docker exec openclaw openclaw --version
docker exec openclaw codex --version
docker exec openclaw openclaw health
docker exec openclaw openclaw channels status --deep
docker exec openclaw openclaw models status
```

В `models status` должны быть:

```text
Default       : openai/gpt-5.6-sol
Runtime auth  : status=usable
OAuth/token status: один рабочий профиль openai:... ok
```

Ожидаемое по Telegram:

```text
Telegram default: enabled, configured, running, connected, mode:polling
Telegram: ok (@...)
```

Smoke test через OpenClaw agent:

```bash
docker exec openclaw bash -lc 'TOKEN=$(node -e "const c=require(\"/root/.openclaw/openclaw.json\"); console.log(c.gateway.auth.token)"); OPENCLAW_GATEWAY_TOKEN="$TOKEN" openclaw agent --session-id codex-smoke --message "Reply with exactly: openclaw-codex-ok" --timeout 120 --json'
```

Ручная отправка в Telegram:

```bash
docker exec openclaw openclaw message send \
  --channel telegram \
  --target <TELEGRAM_CHAT_ID> \
  --message "OpenClaw manual send test" \
  --json
```

## Полезные команды

Посмотреть default agent:

```bash
docker exec openclaw openclaw agents list
docker exec openclaw openclaw config get agents
```

Текущий default agent:

```text
main (default)
Model: openai/gpt-5.6-sol
Telegram default: configured
Routing: default
```

Одобрить Control UI device pairing:

```bash
docker exec openclaw bash -lc 'TOKEN=$(node -e "const c=require(\"/root/.openclaw/openclaw.json\"); console.log(c.gateway.auth.token)"); openclaw devices approve <REQUEST_ID> --token "$TOKEN"'
```

Одобрить Telegram pairing:

```bash
docker exec openclaw openclaw pairing approve telegram <PAIRING_CODE>
```

Перезапуск gateway внутри контейнера:

```bash
docker exec openclaw bash -lc 'TOKEN=$(node -e "const c=require(\"/root/.openclaw/openclaw.json\"); console.log(c.gateway.auth.token)"); pkill -f "openclaw-gateway" 2>/dev/null || true; nohup env OPENCLAW_GATEWAY_TOKEN="$TOKEN" openclaw gateway run --port 18789 --bind lan --auth token --token "$TOKEN" >/root/.openclaw/logs/gateway.out 2>&1 &'
```

Логи:

```bash
docker exec openclaw tail -200 /root/.openclaw/logs/gateway.out
docker exec openclaw tail -200 /tmp/openclaw/openclaw-$(date +%F).log
```

## Telegram

Бот работает в polling mode.

Если Telegram не отвечает:

1. Проверить статус:

   ```bash
   docker exec openclaw openclaw channels status --deep
   ```

2. Проверить health:

   ```bash
   docker exec openclaw bash -lc 'TOKEN=$(node -e "const c=require(\"/root/.openclaw/openclaw.json\"); console.log(c.gateway.auth.token)"); openclaw gateway health --token "$TOKEN"'
   ```

3. Проверить логи:

   ```bash
   docker exec openclaw bash -lc 'tail -400 /tmp/openclaw/openclaw-$(date +%F).log | grep -iE "telegram|auto-reply|sendMessage|failed|error"'
   ```

4. Убедиться, что нет второго polling-процесса для того же Telegram bot token. Ошибка выглядит так:

   ```text
   409: Conflict: terminated by other getUpdates request
   ```

## Bootstrap workspace

OpenClaw создал workspace:

```text
/root/.openclaw/workspace
```

В нем есть `BOOTSTRAP.md`, `IDENTITY.md`, `USER.md`, `SOUL.md`, `TOOLS.md`.

Первый Telegram ответ может просить заполнить identity/user данные. Это нормальное поведение OpenClaw bootstrap. После настройки личности агент может удалить `BOOTSTRAP.md`.

## Monit

Проверка OpenClaw на Docker-хосте:

```text
server/monit/scripts/openclaw_health.sh
server/monit/conf.d/openclaw_health.conf
```

Она проверяет, что контейнер запущен, `openclaw health` проходит, а OAuth runtime
имеет `status=usable` и хотя бы один OAuth-профиль OpenAI со статусом `ok` или
`expiring`, срок действия которого ещё не истёк. Проверка читает JSON и дату
истечения: `expiring` означает приближение срока, а не потерю авторизации.
Если access token истёк, но runtime остаётся `usable`, проверка делает короткий
запрос через работающий gateway, чтобы дать ему обновить токен, затем повторно
проверяет срок. Запрос использует отдельную сессию `monit-oauth-healthcheck`,
без `--deliver`, и ничего не отправляет в Telegram. Он расходует небольшой
объём токенов модели только при истёкшем access token. Ошибка или таймаут
этого запроса остаются аварией; обновление токена не считается успешным без
повторной проверки. `models status --probe` не используется: эта версия
OpenClaw запрещает его при работающем gateway.
Обращение к модели ограничено одной попыткой в час на контейнер, включая
ошибки и таймауты. Время попытки сохраняется до запроса в
`/var/lib/monit/openclaw-health/<container>.last-attempt` и переживает
перезагрузку хоста; `flock` исключает параллельные запросы. Пока час не прошёл,
при всё ещё истёкшем токене Monit сообщает об ошибке и времени до следующей
попытки без запроса к модели. Обычные проверки gateway и авторизации
продолжаются каждый цикл. Если токен обновился другим запросом, статус сразу
становится успешным, без ожидания часа.
Старые просроченные профили не вызывают ошибку, если есть действующий.
Наличие новой
версии OpenClaw не является аварией и не должно влиять на Monit.

Установка на Docker-хосте:

```bash
sudo install -m 0755 /home/dmitriy/.config/server/monit/scripts/openclaw_health.sh /etc/monit/scripts/
sudo install -m 0644 /home/dmitriy/.config/server/monit/conf.d/openclaw_health.conf /etc/monit/conf.d/
sudo monit -t && sudo systemctl reload monit
```

## После изменений

После удачной настройки сохранить образ:

```bash
docker commit openclaw openclaw-debian11-codex-telegram
```

Если токен Telegram будет перевыпущен, обновить его:

```bash
docker exec openclaw openclaw channels add --channel telegram --token '<NEW_TELEGRAM_BOT_TOKEN>'
docker exec openclaw openclaw channels status --deep
```
