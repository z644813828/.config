# MTProto

Короткая документация по локальным файлам и общей схеме развертывания.

## Актуальность VPS1 и VPS3

[Перенос и проверки на 9 ноября 2026 года](VPS-2026-11-09.md): на VPS1
скопированы MTProto, WebProxy, панель и все 13 клиентов VPS3. Старые клиенты
VPS1 заменены по запросу администратора, резервная копия сохранена.

Адреса панелей и реквизиты хранятся в приватных настройках доступа.
Клиентские ссылки и секреты публикуются только внутри авторизованной панели.

Онлайн исправлен на обоих серверах: учитываются локальные адрес/порт
ESTABLISHED-соединений MTG и живые WebProxy-сессии каждого профиля.
В группах показано число клиентов, а не соединений. При недоступности
телеметрии WebProxy отображается «Нет данных», а не ложный «Офлайн».
Патч relay и сборка описаны в [tproxy/README.md](tproxy/README.md).
Учёт трафика различает IPv4-адреса; это важно при одинаковых портах
на нескольких адресах. Переименование сохраняет bind-адрес и существующие
порты вне диапазона выдачи новых портов (например, порт 29443).

Локальный `server-mtproto-admin.php` синхронизирован с VPS3, включая WebProxy
в общей таблице. При редактировании он вызывает `/usr/local/bin/mtproto-edit-user`
(исходник `mtproto-edit-user.py`). Оба файла установлены на VPS3 8 ноября.
Переименование проверено через панель с возвратом исходного имени и сохранением
всех 13 комплектов WebProxy-кнопок.

Helper под блокировкой проверяет имена, порты и конфликты, обновляет MTG,
systemd, WebProxy `profiles.json` и `client-info.json`. Секреты и ссылки WebProxy
не меняются. Дополнительные настройки MTG и прежнее состояние active/enabled
сохраняются; указание нового hostname явно меняет MTG secret.
Активный relay кратко перезапускается, чтобы перечитать имена.
Перед изменениями создаются копии в `/var/backups/mtproto-edit/edit-*`.
При ошибке helper восстанавливает файлы и службы, выводит путь копии.
Блокировка сериализует операции helper; ручные изменения файлов выполнять отдельно.

Панель развёртывается вместе с helper (Python 3, запуск от root, как текущая панель):

```bash
install -m 755 mtproto-edit-user.py /usr/local/bin/mtproto-edit-user
install -m 640 -o root -g www-data server-mtproto-admin.php /opt/mtproto-web/index.php
php -l /opt/mtproto-web/index.php
```

Регрессионные тесты из корня репозитория:

```bash
python3 -m unittest discover -s server/vps -p test_mtproto_edit_user.py -v
```

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

## Бэкапы конфигурации на FTP

На VPS1/VPS2/VPS3 используются одинаковые `vps-config-backup` и systemd units.
Ежедневный `vps-config-backup.timer` запускает архивирование и отправку на FTP.
При ошибке сервис повторяет попытку раз в час до успеха
(`vps-config-backup.service.d/retry.conf`); лимит количества запусков отключён,
чтобы продолжительный сбой FTP не прекращал повторы до следующего дня.
После успешной загрузки сервис завершается и ждёт ежедневного таймера.
Проверка давности `vps-backup-age-alert.timer` остаётся независимой; порог — 36 часов.

```bash
systemctl list-timers --all vps-config-backup.timer vps-backup-age-alert.timer
systemctl show vps-config-backup.service -p Result -p RestartUSec
journalctl -u vps-config-backup.service -n 30 --no-pager
```

Повторный ручной запуск:

```bash
systemctl reset-failed vps-config-backup.service
systemctl start vps-config-backup.service
```

FTP-реквизиты хранятся в `/root/.vps-config-backup.env`. Не публиковать этот файл.

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
