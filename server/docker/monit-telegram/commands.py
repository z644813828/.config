"""Owner-only command polling with single-use, expiring confirmations."""
import logging
import os
import secrets
import time

import monit_api
import telegram_api

HELP = '''🖥 MONIT · Управление

📊 Состояние
/summary — сводка всех проверок
/status имя — состояние одной проверки
/services — имена проверок

⚙️ Управление
/monitor имя — включить мониторинг
/unmonitor имя — отключить мониторинг

📬 Уведомления
/queue — очереди доставки
/help — эта справка

Изменения требуют подтверждения в течение 60 секунд.'''


class Bot:
    def __init__(self, connect, chunks):
        self.connect = connect
        self.chunks = chunks
        self.pending = {}
        self.owner = int(os.environ['TELEGRAM_ALLOWED_USER_ID'])
        self.chat = int(os.environ['TELEGRAM_CHAT_ID'])
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS bot_state (key TEXT PRIMARY KEY, value INTEGER)')

    def reply(self, text, **extra):
        for chunk in self.chunks(text):
            telegram_api.message(chunk, **extra)

    def authorized(self, message, sender):
        chat = message.get('chat', {})
        return (sender.get('id') == self.owner and chat.get('id') == self.chat
                and chat.get('type') == 'private')

    def handle(self, update):
        callback = update.get('callback_query')
        message = (callback or {}).get('message') if callback else update.get('message')
        if not message:
            return
        sender = callback.get('from', {}) if callback else message.get('from', {})
        if not self.authorized(message, sender):
            return
        if callback:
            self.confirm(callback)
            return
        if message.get('date', 0) < time.time() - 120:
            return
        words = message.get('text', '').split(maxsplit=1)
        if not words:
            return
        command = words[0].split('@')[0].lstrip('/')
        name = words[1].strip() if len(words) > 1 else None
        if command in ('help', 'start'):
            self.reply(HELP)
        elif command == 'summary':
            self.reply(monit_api.summary())
        elif command == 'status':
            self.reply(monit_api.status(name) if name else 'Укажите имя: /status имя. Список: /services')
        elif command == 'services':
            self.reply('📋 MONIT · Службы\n\n' + '\n'.join('• ' + name for name in sorted(monit_api.services())) + '\n\nПодробнее: /status имя')
        elif command == 'queue':
            with self.connect() as db:
                count = db.execute('SELECT count(*) FROM queue').fetchone()[0]
                mail_count = db.execute('SELECT count(*) FROM mail_queue').fetchone()[0]
            self.reply('📬 MONIT · Очереди доставки\n\n✈️ Telegram: {} частей\n✉️ Почта: {} получателей'.format(count, mail_count))
        elif command in monit_api.ACTIONS:
            if not name or name == 'all' or name not in monit_api.services():
                self.reply('Укажите одно точное имя из /services: /' + command + ' имя')
                return
            token = secrets.token_hex(12)
            # Only the most recent confirmation remains valid.
            self.pending = {token: (command, name, time.monotonic() + 60)}
            self.reply('⚙️ MONIT · Подтверждение\n\nСлужба: {}\nДействие: {}\n\nПодтвердите в течение 60 секунд.'.format(name, 'Включить мониторинг' if command == 'monitor' else 'Отключить мониторинг'), reply_markup={
                'inline_keyboard': [[{'text': '✅ Подтвердить', 'callback_data': 'yes:' + token},
                                     {'text': '✖️ Отмена', 'callback_data': 'no:' + token}]]})
        else:
            self.reply('Неизвестная команда. /help')

    def confirm(self, callback):
        decision, _, token = callback.get('data', '').partition(':')
        if decision not in ('yes', 'no'):
            return
        pending = self.pending.pop(token, None)
        # Consume before any network call: a failed response must not repeat an action.
        telegram_api.call('answerCallbackQuery', {'callback_query_id': callback['id']})
        if not pending or pending[2] < time.monotonic():
            self.reply('Подтверждение устарело. Отправьте команду заново.')
            return
        if decision == 'no':
            self.reply('↩️ Действие отменено.')
            return
        command, name, _ = pending
        try:
            monit_api.action(name, command)
        except Exception:
            self.reply('Не удалось подтвердить выполнение. Проверьте /status перед повтором команды.')
            return
        self.reply('✅ MONIT · Команда принята\n\nСлужба: {}\nДействие: {}\n\nПроверить: /status {}'.format(name, 'Включить мониторинг' if command == 'monitor' else 'Отключить мониторинг', name))

    def poll(self, stop):
        while not stop.is_set():
            try:
                with self.connect() as db:
                    row = db.execute("SELECT value FROM bot_state WHERE key='offset'").fetchone()
                offset = row[0] if row else 0
                updates = telegram_api.call('getUpdates', {
                    'offset': offset, 'timeout': 25, 'allowed_updates': ['message', 'callback_query']})
                for update in updates:
                    if stop.is_set():
                        return
                    # Persist first: commands are not replayed after a crash.
                    with self.connect() as db:
                        db.execute("INSERT OR REPLACE INTO bot_state(key,value) VALUES ('offset', ?)",
                                   (update['update_id'] + 1,))
                    try:
                        self.handle(update)
                    except Exception:
                        logging.warning('Command failed; check local Monit connection and Telegram settings')
                        message = update.get('message') or update.get('callback_query', {}).get('message', {})
                        sender = update.get('message', {}).get('from') or update.get('callback_query', {}).get('from', {})
                        if self.authorized(message, sender):
                            self.reply('Ошибка запроса. Проверьте настройки Monit и логи контейнера.')
            except Exception:
                logging.warning('Telegram command polling failed; retry in 10s')
                stop.wait(10)
