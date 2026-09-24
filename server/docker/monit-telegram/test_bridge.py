import asyncio
import os
import tempfile
import unittest
from email.message import EmailMessage
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

import bridge


class BridgeTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.db_patch = patch.object(bridge, 'DB', str(Path(self.directory.name) / 'queue.db'))
        self.db_patch.start()
        self.addCleanup(self.db_patch.stop)
        env = patch.dict(os.environ, MAIL_RELAY_ENABLED='false')
        env.start()
        self.addCleanup(env.stop)
        bridge.initialize()

    def receive(self, body='Сервис восстановлен'):
        message = EmailMessage()
        message['Subject'] = 'Monit: проверка 🛠'
        message.set_content(body)
        return asyncio.run(bridge.Handler().handle_DATA(
            None, None, SimpleNamespace(original_content=message.as_bytes(), mail_from='monit@example.com',
                                        rcpt_tos=['owner@example.com', 'second@example.com'])))

    def test_delivery_and_restart(self):
        self.assertTrue(self.receive().startswith('250'))
        bridge.initialize()
        with patch.object(bridge, 'send') as send:
            self.assertTrue(bridge.deliver_one())
            self.assertIn('Monit: проверка 🛠', send.call_args.args[0])
            self.assertIn('Сервис восстановлен', send.call_args.args[0])
            self.assertFalse(bridge.deliver_one())

    def test_failed_delivery_is_retained(self):
        self.receive()
        with patch.object(bridge, 'send', side_effect=OSError('offline')):
            with self.assertRaises(OSError):
                bridge.deliver_one()
        with patch.object(bridge, 'send'):
            self.assertTrue(bridge.deliver_one())

    def test_long_message(self):
        self.receive('😀' * 5000)
        with bridge.connect() as db:
            parts = [row[0] for row in db.execute('SELECT text FROM queue ORDER BY id')]
        self.assertGreater(len(parts), 1)
        self.assertTrue(all(len(part.encode('utf-16-le')) // 2 <= 4096 for part in parts))
        self.assertEqual(''.join(parts).count('😀'), 5000)

    def test_mail_and_telegram_independent_delivery(self):
        with patch.dict(os.environ, MAIL_RELAY_ENABLED='true'):
            self.assertTrue(self.receive().startswith('250'))
        bridge.initialize()
        with patch.object(bridge, 'send', side_effect=OSError('Telegram offline')):
            with self.assertRaises(OSError):
                bridge.deliver_one()
        with patch('bridge.smtplib.SMTP') as smtp:
            client = smtp.return_value.__enter__.return_value
            client.sendmail.return_value = {}
            self.assertTrue(bridge.deliver_mail_one())
            self.assertEqual(client.sendmail.call_args.args[:2], ('monit@example.com', ['owner@example.com']))
            self.assertIn(b'Subject:', client.sendmail.call_args.args[2])
            self.assertTrue(bridge.deliver_mail_one())
            self.assertEqual(client.sendmail.call_args.args[1], ['second@example.com'])
            self.assertFalse(bridge.deliver_mail_one())
        with patch.object(bridge, 'send'):
            self.assertTrue(bridge.deliver_one())
            self.assertFalse(bridge.deliver_one())

    def test_mail_failure_retained_without_blocking_telegram(self):
        with patch.dict(os.environ, MAIL_RELAY_ENABLED='true'):
            self.receive()
        with patch('bridge.smtplib.SMTP', side_effect=OSError('SMTP offline')):
            with self.assertRaises(OSError):
                bridge.deliver_mail_one()
        with patch.object(bridge, 'send'):
            self.assertTrue(bridge.deliver_one())
        with bridge.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM mail_queue').fetchone()[0], 2)

    def test_both_queues_rollback_on_mail_storage_failure(self):
        with bridge.connect() as db:
            db.execute("CREATE TRIGGER fail_mail BEFORE INSERT ON mail_queue BEGIN SELECT RAISE(ABORT, 'full'); END")
        with patch.dict(os.environ, MAIL_RELAY_ENABLED='true'):
            self.assertTrue(self.receive().startswith('451'))
        with bridge.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM queue').fetchone()[0], 0)
            self.assertEqual(db.execute('SELECT count(*) FROM mail_queue').fetchone()[0], 0)

    def test_storage_failure_returns_temporary_smtp_error(self):
        with patch.object(bridge, 'connect', side_effect=OSError('disk full')):
            self.assertTrue(self.receive().startswith('451'))


if __name__ == '__main__':
    unittest.main()
