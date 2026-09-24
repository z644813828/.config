#!/usr/bin/env python3
"""Accept Monit mail on loopback and durably queue it for Telegram."""
import email.policy
import logging
import os
import signal
import smtplib
import sqlite3
import threading
from contextlib import contextmanager
from email.parser import BytesParser
from pathlib import Path

import telegram_api

DB = os.environ.get('QUEUE_DB', '/var/lib/monit-telegram/queue.sqlite3')


@contextmanager
def connect():
    db = sqlite3.connect(DB, timeout=10)
    try:
        with db:
            yield db
    finally:
        db.close()


def initialize():
    Path(DB).parent.mkdir(parents=True, exist_ok=True)
    with connect() as db:
        db.execute('CREATE TABLE IF NOT EXISTS queue (id INTEGER PRIMARY KEY, text TEXT NOT NULL)')
        db.execute('CREATE TABLE IF NOT EXISTS mail_queue ('
                   'id INTEGER PRIMARY KEY, sender TEXT NOT NULL, recipient TEXT NOT NULL, raw BLOB NOT NULL)')


def message_text(raw):
    message = BytesParser(policy=email.policy.default).parsebytes(raw)
    part = message.get_body(preferencelist=('plain', 'html'))
    body = part.get_content() if part else ''
    subject = str(message.get('Subject', 'Уведомление'))
    return '🔔 MONIT · Уведомление\n\n{}\n\n{}'.format(subject, body.strip()).strip()


def chunks(text):
    # Stay below Telegram's limit even for UTF-16 surrogate pairs.
    result = []
    while text:
        end = min(2000, len(text))
        if end < len(text):
            newline = text.rfind('\n', 0, end)
            if newline > 0:
                end = newline + 1
        result.append(text[:end])
        text = text[end:]
    return result


class Handler:
    async def handle_DATA(self, server, session, envelope):
        try:
            with connect() as db:
                db.executemany('INSERT INTO queue(text) VALUES (?)',
                               [(part,) for part in chunks(message_text(envelope.original_content))])
                if os.environ.get('MAIL_RELAY_ENABLED', 'false').lower() == 'true':
                    db.executemany('INSERT INTO mail_queue(sender, recipient, raw) VALUES (?, ?, ?)',
                                   [(envelope.mail_from, recipient, envelope.original_content)
                                    for recipient in dict.fromkeys(envelope.rcpt_tos)])
        except Exception:
            logging.error('Cannot persist SMTP message')
            return '451 Temporary queue failure'
        return '250 Queued'


def send(text):
    telegram_api.message(text)


def deliver_one():
    with connect() as db:
        row = db.execute('SELECT id, text FROM queue ORDER BY id LIMIT 1').fetchone()
    if row is None:
        return False
    send(row[1])
    with connect() as db:
        db.execute('DELETE FROM queue WHERE id = ?', (row[0],))
    return True


def deliver_mail_one():
    with connect() as db:
        row = db.execute('SELECT id, sender, recipient, raw FROM mail_queue ORDER BY id LIMIT 1').fetchone()
    if row is None:
        return False
    # Original local MTA, distinct from the bridge's listening port 2525.
    # SMTP does not use the HTTP proxy configured for Telegram.
    with smtplib.SMTP('127.0.0.1', 25, timeout=30) as smtp:
        refused = smtp.sendmail(row[1], [row[2]], row[3])
        if refused:
            raise RuntimeError('Mail recipient refused')
    with connect() as db:
        db.execute('DELETE FROM mail_queue WHERE id = ?', (row[0],))
    return True


def mail_worker(stop):
    while not stop.is_set():
        try:
            if not deliver_mail_one():
                stop.wait(2)
        except Exception:
            logging.warning('Mail delivery failed; queued message retained; retry in 60s')
            stop.wait(60)


def main():
    from aiosmtpd.controller import Controller
    logging.basicConfig(level=logging.WARNING)
    for key in ('TELEGRAM_BOT_TOKEN', 'TELEGRAM_CHAT_ID'):
        if not os.environ.get(key):
            raise SystemExit('Missing ' + key)
    initialize()
    stop = threading.Event()
    for sig in (signal.SIGTERM, signal.SIGINT):
        signal.signal(sig, lambda *_: stop.set())
    controller = Controller(Handler(), hostname='127.0.0.1', port=2525,
                            data_size_limit=1024 * 1024, decode_data=False)
    bot = None
    if os.environ.get('TELEGRAM_ALLOWED_USER_ID'):
        from commands import Bot
        bot = Bot(connect, chunks)
    controller.start()
    mail_thread = threading.Thread(target=mail_worker, args=(stop,), daemon=True)
    mail_thread.start()
    worker = None
    if bot:
        worker = threading.Thread(target=bot.poll, args=(stop,), daemon=True)
        worker.start()
    try:
        while not stop.is_set():
            try:
                if not deliver_one():
                    stop.wait(2)
            except Exception:
                # Exception URLs can contain the bot token; never log them.
                logging.warning('Telegram delivery failed; queued message retained; retry in 60s')
                stop.wait(60)
    finally:
        stop.set()
        controller.stop()
        mail_thread.join(timeout=35)
        if worker:
            worker.join(timeout=45)


if __name__ == '__main__':
    main()
