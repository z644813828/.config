# MTProto

Короткая документация по локальным файлам и общей схеме развертывания.

## Что установлено

- `mtg` - MTProto proxy binary: `/usr/local/bin/mtg`.
- Пользователи MTProto - отдельные systemd-сервисы `mtg-<User>.service`.
- Конфиги пользователей - `/etc/mtg-<User>.toml`.
- Веб-панель MTProto - PHP-файл, который обслуживается отдельным web-service, например `/opt/mtproto-web/index.php`.
- HTTPS-доступ к веб-панели - `mtproto-web.service` + `mtproto-web-tls.service`.
- Автоподхват нового TLS-сертификата для MTProto UI - `mtproto-web-tls-reload.path` + `mtproto-web-tls-reload.service`.
- Мониторинг трафика - `/usr/local/bin/mtproto-traffic`.
- 3x-ui:
  - бинарник `/usr/local/x-ui/x-ui`
  - настройки панели хранятся в SQLite
  - runtime-конфиг Xray хранится отдельно

## Пример боевой схемы

- 3x-ui panel:
  - отдельный HTTPS-порт
  - отдельный base path
- MTProto web UI:
  - backend на loopback-интерфейсе
  - HTTPS wrapper на отдельном внешнем порту
- TLS-файлы для 3x-ui и MTProto UI:
  - `fullchain.pem`
  - `privkey.pem`
  - часто используются из отдельного каталога сертификатов
- Swap:
  - отдельный swapfile
- journald ограничен:
  - `SystemMaxUse=50M`
  - `RuntimeMaxUse=30M`
  - `MaxRetentionSec=7day`

## Основные команды

```bash
/usr/local/bin/mtproto-traffic sync
/usr/local/bin/mtproto-traffic collect
/usr/local/bin/mtproto-traffic report
/usr/local/bin/mtproto-traffic report-month
/usr/local/bin/mtproto-traffic forget <user_name>
```

Локальный helper для работы по SSH:

```bash
./mtproto-cli.sh list
./mtproto-cli.sh status <user_name>
./mtproto-cli.sh access <user_name>
./mtproto-cli.sh traffic
./mtproto-cli.sh remove <user_name>
```

## Что делает collect

`mtproto-traffic collect` запускает тот же скрипт `mtproto-traffic`, но с аргументом `collect`.

`collect` снимает текущие byte counters из `iptables-save -c`, считает разницу с прошлым снимком и обновляет файлы статистики:

- `/var/lib/mtproto-traffic/last.tsv` - последний снимок счетчиков iptables.
- `/var/lib/mtproto-traffic/totals.tsv` - общий трафик за все время.
- `/var/lib/mtproto-traffic/month.tsv` - трафик текущего месяца.
- `/var/lib/mtproto-traffic/month.marker` - текущий месяц в формате `YYYY-MM`.

Если счетчик iptables сбросился, скрипт не вычитает отрицательное значение, а считает текущий счетчик новым приростом.

## Что делает sync

`sync` синхронизирует правила iptables с текущими MTProto-пользователями.

Последовательность:

1. Сначала делает снимок текущего трафика, чтобы не потерять байты перед пересозданием правил.
2. Создает цепочки `MTPROTO_TRAFFIC_IN` и `MTPROTO_TRAFFIC_OUT`, если их еще нет.
3. Подключает эти цепочки к `INPUT` и `OUTPUT`.
4. Читает пользователей из `/etc/mtg-*.toml`.
5. Пересоздает правила по портам пользователей с комментариями вида `mtproto:<user>:in` и `mtproto:<user>:out`.
6. Очищает `last.tsv` и сразу запускает `collect`.

`sync` нужно запускать после добавления, удаления или переименования MTProto-пользователей.

## systemd

- `mtproto-traffic-sync.service` - один раз синхронизирует iptables-правила при старте системы.
- `mtproto-traffic-collect.service` - один раз запускает `collect`.
- `mtproto-traffic-collect.timer` - запускает `collect` каждую минуту.
- `mtproto-web.service` - PHP built-in server для MTProto UI.
- `mtproto-web-tls.service` - TLS-обертка `socat` для MTProto UI.
- `mtproto-web-tls-reload.path` - следит за изменением cert/key.
- `mtproto-web-tls-reload.service` - автоматически перезапускает `mtproto-web-tls.service` после обновления сертификата.

Проверка:

```bash
systemctl status mtproto-traffic-sync.service
systemctl status mtproto-traffic-collect.timer
systemctl status mtproto-web.service
systemctl status mtproto-web-tls.service
systemctl status mtproto-web-tls-reload.path
journalctl -u mtproto-traffic-collect.service -n 50 --no-pager
```

## Веб-панель

Веб-панель читает:

- пользователей из `/etc/mtg-*.toml`;
- статусы сервисов через `systemctl`;
- онлайн через `ss` по активным TCP-соединениям на порт пользователя;
- трафик через `mtproto-traffic report-tsv` и `report-month-tsv`.

Создание, редактирование, выключение и удаление пользователя выполняются через systemd и файлы `/etc/mtg-*.toml`.

Дополнительно в UI уже есть:

- автообновление без полной перезагрузки страницы;
- compact mode;
- health-check блок снизу страницы.

## Сертификаты

`mtproto-web-tls.service` использует `socat`, который читает cert/key только при старте.

Чтобы MTProto UI не оставался на старом сертификате после обновления файлов, добавлен watcher:

- `mtproto-web-tls-reload.path`
- `mtproto-web-tls-reload.service`

Он автоматически делает:

```bash
systemctl restart mtproto-web-tls.service
```

при изменении файлов сертификата, например `fullchain.pem` и `privkey.pem`.

## 3x-ui

В этой установке настройки 3x-ui лежат не в `config.json`, а в SQLite.

Типичный путь к БД панели: `/etc/x-ui/x-ui.db`.

Полезные ключи в таблице `settings`:

- `webPort`
- `webBasePath`
- `webCertFile`
- `webKeyFile`
- `tgBotEnable`
- `tgBotToken`
- `tgBotChatId`
- `tgBotLoginNotify`
- `tgCpu`
- `tgRunTime`

Типичный runtime-конфиг Xray для 3x-ui: `/usr/local/x-ui/bin/config.json`.

## Системные примечания

На сервере уже включены:

- swap-файл `1G` в `/swapfile`;
- ограничение `journald` через `/etc/systemd/journald.conf.d/limits.conf`.

Проверка:

```bash
free -h
swapon --show
journalctl --disk-usage
```
