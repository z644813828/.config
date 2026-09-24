# Уведомления Monit в Telegram

Мост принимает письма Monit на `127.0.0.1:2525`, сохраняет в SQLite и отправляет
тему и текст в Telegram. Существующие `alert`, `noalert` и шаблоны остаются в силе.
При `MAIL_RELAY_ENABLED=true` уведомления также пересылаются на прежний локальный
SMTP-сервер `127.0.0.1:25` для доставки на почту. Без этой переменной работает только Telegram.
Внешний порт открывать не нужно. Для Debian 9 используйте Docker-вариант ниже:
Python и зависимости находятся внутри контейнера. Совместимость с конкретными
версиями Docker и ядра на вашем сервере нужно проверить запуском.

## Настройка

1. Создайте бота командой `/newbot` у [@BotFather](https://t.me/BotFather).
2. Откройте личный чат с ботом и нажмите Start.
3. Получите свой `message.chat.id` через Telegram Bot API `getUpdates`.
   Например, выполните локально код ниже. Он скрыто запросит токен и выведет
   только идентификаторы чатов; токен не попадёт в историю команд.
   У нового бота без сообщений ответ пуст: сначала отправьте ему сообщение.

   ```sh
   python3 - <<'PY'
   import getpass, json, urllib.request
   token = getpass.getpass('Bot token: ')
   try:
       with urllib.request.urlopen('https://api.telegram.org/bot' + token + '/getUpdates', timeout=30) as r:
           for update in json.load(r).get('result', []):
               chat = update.get('message', {}).get('chat')
               if chat:
                   print(chat['id'], chat.get('first_name', ''), chat.get('title', ''))
   except Exception:
       print('Не удалось получить chat_id. Проверьте токен и доступ к Telegram.')
   PY
   ```

## Docker на Debian 9

Используется образ `python:3.11-slim-bullseye` и Compose формата 2 для старого
`docker-compose`. Это временный вариант для старого сервера. Установленный Docker
должен уметь скачивать и запускать этот образ; обновлять системный Python не нужно.

Из этой папки на сервере (файл env создайте только при первой установке):

```sh
sudo install -m 600 env.example /etc/monit-telegram.env
sudoedit /etc/monit-telegram.env
sudo docker-compose up -d --build
sudo docker logs --tail 50 monit-telegram
```

Укажите в env токен и chat_id. При наличии Compose v2 замените `docker-compose`
на `docker compose`. Если ранее запускали мост как systemd-сервис, сначала
остановите его: `sudo systemctl disable --now monit-telegram` — порт общий.

Контейнер использует сеть хоста, а приложение слушает только `127.0.0.1:2525`.
Monit на хосте сможет подключиться по этому адресу. `ports` не нужны.
Очередь хранится в именованном Docker-томе `queue` и переживает пересоздание
контейнера. Не выполняйте `docker-compose down -v`: это удалит очередь.
Очередь прежнего systemd-сервиса автоматически в Docker не переносится;
перед переходом дождитесь её отправки.

Если Compose отсутствует, можно запустить тот же образ напрямую
(выберите один способ запуска):

```sh
sudo docker build -t local/monit-telegram .
sudo docker run -d --name monit-telegram --restart unless-stopped \
  --network host --env-file /etc/monit-telegram.env \
  --read-only --cap-drop ALL --security-opt no-new-privileges:true \
  --log-opt max-size=5m --log-opt max-file=2 \
  -v monit-telegram-queue:/var/lib/monit-telegram local/monit-telegram
```

Для проверки из раздела ниже замените `python3 -` на
`sudo docker exec -i monit-telegram python -`: тест выполнится внутри контейнера.
Диагностика: `sudo docker logs --tail 50 monit-telegram`.
Обновление через Compose: `sudo docker-compose up -d --build`.
При изменении env тоже выполните эту команду для пересоздания контейнера.

## Установка без Docker (современный сервер)

Требуются Python 3.9+ и systemd с поддержкой `StateDirectory`.
Из этой папки на сервере:

```sh
sudo apt-get install python3-venv
sudo useradd --system --user-group --home-dir /var/lib/monit-telegram --shell /usr/sbin/nologin monit-telegram
sudo install -d /opt/monit-telegram
sudo install -m 644 bridge.py telegram_api.py monit_api.py commands.py requirements.txt /opt/monit-telegram/
sudo python3 -m venv /opt/monit-telegram/venv
sudo /opt/monit-telegram/venv/bin/pip install -r /opt/monit-telegram/requirements.txt
sudo install -m 600 env.example /etc/monit-telegram.env
sudoedit /etc/monit-telegram.env
sudo install -m 644 monit-telegram.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now monit-telegram
```

В `/etc/monit-telegram.env` укажите токен и chat_id. Не добавляйте этот файл в Git.
Если пользователь `monit-telegram` уже существует, пропустите `useradd`.

## Проверка и переключение

Сначала отправьте тестовое письмо в мост:

```sh
python3 - <<'PY'
import smtplib
from email.message import EmailMessage
message = EmailMessage()
message['From'] = 'monit@localhost'
message['To'] = 'telegram@localhost'
message['Subject'] = 'Monit: проверка Telegram'
message.set_content('Доставка уведомлений работает.')
with smtplib.SMTP('127.0.0.1', 2525) as smtp:
    smtp.send_message(message)
PY
```

После получения сообщения замените в `/etc/monit/monitrc` строку `set mailserver`:

```monit
set mailserver 127.0.0.1 port 2525 with timeout 15 seconds
```

Оставьте `set alert` и `set eventqueue`: адрес получателя служит Monit для выбора
правил, мост отправляет все принятые уведомления в заданный chat_id.
Примените: `sudo monit -t && sudo systemctl reload monit`.
В репозитории рабочая настройка почты намеренно сохранена до настройки бота.

Диагностика для установки без Docker: `sudo journalctl -u monit-telegram -n 50`.
Если Telegram недоступен, мост сохраняет очередь и повторяет отправку каждые
60 секунд. Длинные сообщения разбиваются на части. При сбое после отправки,
но до удаления из очереди возможен повтор. Очередь не имеет лимита: при долгом
простое проверяйте свободное место в `/var/lib/monit-telegram`
(при Docker-установке — в томе очереди).
Если мост недоступен, действует существующая очередь Monit (в этой конфигурации
100 событий). Локальные процессы тоже могут отправлять письма в мост.

Откат: верните прежнюю строку `set mailserver`, проверьте `monit -t` и перезагрузите
конфигурацию Monit. Уже принятые мостом сообщения остаются в его очереди.

Документация: [Monit SMTP и очередь](https://mmonit.com/monit/documentation/monit.html),
[Telegram Bot API](https://core.telegram.org/bots/api#sendmessage).

Docker: [сеть хоста](https://docs.docker.com/engine/network/drivers/host/),
[базовый образ](https://hub.docker.com/_/python/tags?name=3.11-slim-bullseye).

## Команды Telegram

Команды включаются переменной `TELEGRAM_ALLOWED_USER_ID`. Без неё мост по-прежнему
только отправляет уведомления. Добавьте в существующий `/etc/monit-telegram.env`
(сохраните токен, chat_id и прокси):

```ini
TELEGRAM_ALLOWED_USER_ID=YOUR_TELEGRAM_USER_ID
MONIT_URL=https://127.0.0.1:2812
MONIT_USERNAME=admin
MONIT_PASSWORD=ваш_пароль_Monit
```

Пароль берётся из `allow admin:...` в `/etc/monit/monitrc`. Для локального Monit с
самоподписанным сертификатом можно добавить `MONIT_TLS_VERIFY=false`. Эта настройка
относится только к Monit на loopback; проверка сертификата Telegram остаётся включённой.
По умолчанию проверка сертификата Monit включена; собственный CA можно подключить
через `MONIT_CA_FILE` и read-only bind mount его файла в контейнер.
Monit вызывается напрямую, независимо от `HTTPS_PROXY`.

Обновите файлы приложения, Dockerfile и `.dockerignore` на сервере, затем:

```sh
cd /srv/dev-disk-by-label-Data/docker/compose/monit-telegram
sudo docker-compose up -d --build --force-recreate
```

В личном чате с ботом:

| Команда | Действие |
| --- | --- |
| `/help` или `/start` | Справка |
| `/services` | Точные имена проверок Monit |
| `/summary` | Сводка состояния всех проверок |
| `/status имя` | Подробный статус выбранной проверки |
| `/monitor имя` | Включить мониторинг выбранной проверки |
| `/unmonitor имя` | Отключить мониторинг выбранной проверки |
| `/queue` | Число частей уведомлений, ожидающих отправки |

`monitor`/`unmonitor` требуют подтверждения кнопкой в течение 60 секунд.
Действительна только последняя предложенная операция; после перезапуска бота
подтверждения недействительны. Имя `all` не разрешено. Ответ о принятии команды
не означает, что Monit уже завершил действие — проверяйте `/status имя`.
Изменения применяются по правилам Monit, включая зависимости между проверками.

Бот сверяет и ID отправителя, и ID личного чата. Команды из групп и от других
пользователей игнорируются. Команды старше двух минут игнорируются. Смещение
`getUpdates` хранится в томе очереди, чтобы после перезапуска не выполнять старые
команды повторно. При аварии между сохранением смещения и обработкой команда
может быть пропущена: проверьте статус и отправьте её заново.

Для бота должен работать только один получатель `getUpdates`; webhook должен быть
отключён. Команды принимаются через long polling, входящий порт Telegram не нужен.
Настроить меню можно через `/setcommands` в @BotFather:

```text
summary - Сводка Monit
status - Статус выбранной проверки
services - Список проверок
monitor - Включить мониторинг
unmonitor - Отключить мониторинг
queue - Очередь уведомлений
help - Справка
```

## Одновременно почта и Telegram

В существующий `/etc/monit-telegram.env` добавьте:

```ini
MAIL_RELAY_ENABLED=true
```

Обновите `bridge.py` и `commands.py`, пересоберите и пересоздайте контейнер:

```sh
cd /srv/dev-disk-by-label-Data/docker/compose/monit-telegram
sudo docker-compose up -d --build --force-recreate
```

Monit продолжает отправлять на `127.0.0.1:2525`. Мост атомарно сохраняет письмо
в очередь Telegram и отдельную почтовую очередь, затем передаёт исходное письмо
на `127.0.0.1:25` с оригинальными SMTP-адресами отправителя и получателей.
Прежний почтовый сервер должен оставаться запущенным и настроенным на доставку
наружу; он не должен пересылать письма обратно на порт 2525.
HTTP-прокси используется только для Telegram.

Оба канала обрабатываются независимо: сбой Telegram не задерживает почту и наоборот.
Очереди переживают перезапуск контейнера. `/queue` показывает обе очереди.
После принятия письма локальным SMTP дальнейшими повторами и доставкой управляет
почтовый сервер. При сбое после отправки, но до удаления из SQLite возможен дубль.
Новые письма попадают в обе очереди только после включения переменной; ранее
принятые уведомления Telegram задним числом на почту не отправляются. Отключение
переменной прекращает постановку новых писем, но уже сохранённая почтовая очередь
продолжает отправляться.

Для проверки повторите SMTP-тест выше, заменив `telegram@localhost` в `To` на
ваш настоящий почтовый адрес. Проверьте получение сообщения в обоих каналах.

## Переименование папки установки

В репозитории приложение находится в `server/docker/monit-telegram`.
Если на сервере папка всё ещё называется `telegram`, используйте её фактический путь.
При переносе работающей установки в папку `monit-telegram` сохраните имя Compose-проекта,
чтобы использовать прежний том очереди и существующий контейнер. Узнайте имя:

```sh
sudo docker inspect -f '{{index .Config.Labels "com.docker.compose.project"}}' monit-telegram
```

Укажите полученное значение как `COMPOSE_PROJECT_NAME` в файле `.env` новой папки
(например, `COMPOSE_PROJECT_NAME=telegram`, если команда вернула `telegram`).
После этого выполняйте обычный `docker-compose up -d --build` из новой папки.
