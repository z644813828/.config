"""Telegram transport; urllib honors HTTPS_PROXY from the environment."""
import json
import os
import urllib.request


def call(method, payload):
    request = urllib.request.Request(
        'https://api.telegram.org/bot' + os.environ['TELEGRAM_BOT_TOKEN'] + '/' + method,
        data=json.dumps(payload).encode(), headers={'Content-Type': 'application/json'})
    with urllib.request.urlopen(request, timeout=40) as response:
        result = json.load(response)
    if not result.get('ok'):
        raise RuntimeError('Telegram rejected request')
    return result.get('result')


def message(text, **extra):
    return call('sendMessage', dict(chat_id=os.environ['TELEGRAM_CHAT_ID'], text=text, **extra))
