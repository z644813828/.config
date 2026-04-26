# OpenClaw

Короткая документация по текущей установке OpenClaw в Docker-контейнере.

## Что поднято

- Docker image был зафиксирован после настройки как `openclaw-debian11-codex-telegram`.
- Контейнер называется `openclaw`.
- Внутри контейнера:
  - Debian 11;
  - Node.js `v24.15.0`;
  - npm `11.12.1`;
  - OpenClaw `2026.4.24`;
  - Codex CLI `0.125.0`;
  - `bubblewrap`;
  - Telegram channel.
- OpenClaw Gateway слушает внутри контейнера:
  - `0.0.0.0:18789`;
  - auth mode: `token`;
  - default model: `openai-codex/gpt-5.5`.
- Docker ports:
  - host `2022` -> container `22` for SSH;
  - host `18789` -> container `18789` for OpenClaw Gateway HTTP/WebSocket.
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
- Codex OAuth:
  - `/root/.codex/auth.json`
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

Gateway token брать из контейнера:

```bash
docker exec openclaw node -e 'const c=require("/root/.openclaw/openclaw.json"); console.log(c.gateway.auth.token)'
```

## Проверка

```bash
docker ps --filter name=openclaw
docker exec openclaw openclaw --version
docker exec openclaw codex --version
docker exec openclaw openclaw gateway status
docker exec openclaw openclaw channels status --deep
docker exec openclaw openclaw models list
```

Ожидаемое по моделям:

```text
openai-codex/gpt-5.5 ... Auth yes ... default
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
Model: openai-codex/gpt-5.5
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
