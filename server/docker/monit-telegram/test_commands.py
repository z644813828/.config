import os
from http.server import BaseHTTPRequestHandler, HTTPServer
import tempfile
import threading
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import bridge
import commands
import monit_api


class CommandsTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        for mocker in (patch.object(bridge, 'DB', str(Path(directory.name) / 'queue.db')),
                       patch.dict(os.environ, TELEGRAM_ALLOWED_USER_ID='123456789', TELEGRAM_CHAT_ID='123456789')):
            mocker.start()
            self.addCleanup(mocker.stop)
        bridge.initialize()
        self.bot = commands.Bot(bridge.connect, bridge.chunks)
        self.out = patch('telegram_api.message').start()
        self.api = patch('telegram_api.call').start()
        self.services = patch('monit_api.services', return_value={'sshd': {'monitor': '1', 'status': '0'}}).start()
        self.action = patch('monit_api.action').start()
        self.addCleanup(patch.stopall)

    def message(self, text, user=123456789, chat=123456789, kind='private', date=None):
        return {'update_id': 1, 'message': {'from': {'id': user}, 'chat': {'id': chat, 'type': kind},
                'date': time.time() if date is None else date, 'text': text}}

    def callback(self, token, decision='yes', user=123456789):
        return {'callback_query': {'id': 'cb', 'from': {'id': user},
                'message': {'chat': {'id': 123456789, 'type': 'private'}},
                'data': decision + ':' + token}}

    def test_unauthorized_and_group_commands(self):
        for update in (self.message('/monitor sshd', user=7),
                       self.message('/monitor sshd', chat=7),
                       self.message('/monitor sshd', kind='group')):
            self.bot.handle(update)
        self.out.assert_not_called()
        self.services.assert_not_called()

    def test_single_use_confirmation_and_sender_check(self):
        self.bot.handle(self.message('/monitor sshd'))
        self.action.assert_not_called()
        token = next(iter(self.bot.pending))
        self.bot.handle(self.callback(token, user=7))
        self.action.assert_not_called()
        self.bot.handle(self.callback(token))
        self.bot.handle(self.callback(token))
        self.action.assert_called_once_with('sshd', 'monitor')

    def test_cancel_expire_and_stale_commands(self):
        self.bot.handle(self.message('/unmonitor sshd', date=0))
        self.out.assert_not_called()
        self.bot.handle(self.message('/unmonitor sshd'))
        token = next(iter(self.bot.pending))
        self.bot.handle(self.callback(token, decision='no'))
        self.bot.handle(self.message('/unmonitor sshd'))
        token = next(iter(self.bot.pending))
        self.bot.pending[token] = ('unmonitor', 'sshd', 0)
        self.bot.handle(self.callback(token))
        self.action.assert_not_called()

    def test_disallowed_actions_and_services(self):
        for text in ('/restart sshd', '/monitor all', '/unmonitor unknown'):
            self.bot.handle(self.message(text))
        self.assertFalse(self.bot.pending)
        self.action.assert_not_called()

    def test_summary_and_specific_status(self):
        self.bot.handle(self.message('/summary'))
        self.assertIn('✅ В норме · 1', self.out.call_args.args[0])
        self.assertIn('• sshd', self.out.call_args.args[0])
        with patch('monit_api.status', return_value='sshd details') as status:
            self.bot.handle(self.message('/status sshd'))
            status.assert_called_once_with('sshd')

    def test_offset_persisted_before_handling(self):
        stop = threading.Event()
        self.api.return_value = [self.message('/help')]
        def handle(update):
            with bridge.connect() as db:
                self.assertEqual(db.execute("SELECT value FROM bot_state WHERE key='offset'").fetchone()[0], 2)
            stop.set()
        with patch.object(self.bot, 'handle', side_effect=handle):
            self.bot.poll(stop)
        new_bot = commands.Bot(bridge.connect, bridge.chunks)
        stop.clear()
        def poll_call(method, payload):
            self.assertEqual(payload['offset'], 2)
            stop.set()
            return []
        self.api.side_effect = poll_call
        new_bot.poll(stop)


class MonitTest(unittest.TestCase):
    def test_specific_status_only(self):
        xml = b'<monit><service><name>sshd</name><status>0</status><pid>123</pid></service><service><name>other</name><pid>456</pid></service></monit>'
        with patch('monit_api.request', return_value=xml):
            status = monit_api.status('sshd')
            self.assertIn('123', status)
            self.assertNotIn('456', status)
            self.assertNotIn('other', status)

    def test_action_encoded_and_validated(self):
        with patch('monit_api.services', return_value={'a&b': {}}), patch('monit_api.request') as request:
            monit_api.action('a&b', 'monitor')
            self.assertEqual(request.call_args.args, ('/_doaction', b'service=a%26b&action=monitor'))
            for name, action in [('all', 'monitor'), ('a&b', 'restart'), ('unknown', 'unmonitor')]:
                with self.assertRaises(ValueError):
                    monit_api.action(name, action)

    def test_http_transport_bypasses_proxy_and_authenticates(self):
        seen = []
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                seen.append((self.path, self.headers.get('Authorization')))
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'<monit><service><name>sshd</name><status>0</status><monitor>1</monitor></service></monit>')

            def log_message(self, *args):
                pass

        server = HTTPServer(('127.0.0.1', 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with patch.dict(os.environ, MONIT_URL='http://127.0.0.1:' + str(server.server_port),
                            MONIT_USERNAME='admin', MONIT_PASSWORD='secret',
                            HTTP_PROXY='http://127.0.0.1:1', NO_PROXY='', no_proxy=''):
                self.assertIn('sshd', monit_api.services())
            self.assertEqual(seen, [('/_status?format=xml', 'Basic YWRtaW46c2VjcmV0')])
        finally:
            server.shutdown()
            server.server_close()
            worker.join()

    def test_local_only_url(self):
        with patch.dict(os.environ, MONIT_URL='https://example.com:2812'):
            with self.assertRaises(ValueError):
                monit_api.request('/_status')


if __name__ == '__main__':
    unittest.main()
