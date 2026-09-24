"""Local Monit HTTP interface; never route credentials through Telegram proxy."""
import base64
import os
import ssl
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

ACTIONS = {'monitor', 'unmonitor'}


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(path, data=None):
    url = os.environ.get('MONIT_URL', 'https://127.0.0.1:2812').rstrip('/')
    parsed = urllib.parse.urlsplit(url)
    if parsed.scheme not in ('http', 'https') or parsed.hostname not in ('127.0.0.1', 'localhost', '::1'):
        raise ValueError('MONIT_URL must point to loopback')
    if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path:
        raise ValueError('MONIT_URL must contain only scheme, host and port')
    context = ssl.create_default_context(cafile=os.environ.get('MONIT_CA_FILE') or None)
    if os.environ.get('MONIT_TLS_VERIFY', 'true').lower() == 'false':
        # Explicit opt-out for local self-signed Monit certificates only.
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}),
                                        urllib.request.HTTPSHandler(context=context), NoRedirect())
    headers = {}
    user = os.environ.get('MONIT_USERNAME', '')
    if user:
        credentials = (user + ':' + os.environ.get('MONIT_PASSWORD', '')).encode()
        headers['Authorization'] = 'Basic ' + base64.b64encode(credentials).decode()
    if data is not None:
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    req = urllib.request.Request(url + path, data=data, headers=headers)
    with opener.open(req, timeout=15) as response:
        return response.read(2 * 1024 * 1024)


def services():
    root = ET.fromstring(request('/_status?format=xml'))
    if root.tag != 'monit':
        raise ValueError('Unexpected Monit response')
    result = {}
    for item in root.findall('.//service'):
        name = item.findtext('name')
        if name:
            result[name] = {'status': item.findtext('status', '?'),
                            'monitor': item.findtext('monitor', '?')}
    return result


def action(name, command):
    if command not in ACTIONS or name == 'all' or name not in services():
        raise ValueError('Unknown service or action')
    request('/_doaction', urllib.parse.urlencode({'service': name, 'action': command}).encode())


def state(value):
    monitor = value.get('monitor', '?')
    if monitor == '0':
        return '⏸', 'Мониторинг выключен'
    if monitor == '2':
        return '⏳', 'Инициализация'
    if monitor != '1':
        return '❔', 'Состояние мониторинга: ' + monitor
    if value.get('status') == '0':
        return '✅', 'В норме'
    return '🔴', 'Ошибка · код ' + value.get('status', '?')


def summary(name=None):
    items = services()
    if name:
        if name not in items:
            return '🔎 Служба не найдена\n\nСписок доступных: /services'
        items = {name: items[name]}
    groups = {}
    for key, value in items.items():
        icon, label = state(value)
        groups.setdefault(icon, []).append((key, label))
    lines = ['🖥 MONIT · Сводка', 'Всего служб: ' + str(len(items))]
    for icon, title in [('🔴', 'Требуют внимания'), ('❔', 'Неизвестное состояние'),
                        ('⏳', 'Инициализация'), ('⏸', 'Мониторинг выключен'), ('✅', 'В норме')]:
        rows = groups.get(icon, [])
        if rows:
            lines.extend(['', '{} {} · {}'.format(icon, title, len(rows))])
            for key, label in sorted(rows):
                lines.append('  • ' + key + (' — ' + label if icon in ('🔴', '❔') else ''))
    lines.extend(['', 'Подробнее: /status имя'])
    return '\n'.join(lines)


LABELS = {
    'pid': 'PID', 'ppid': 'Родительский PID', 'uptime': 'Время работы',
    'cpu/percent': 'CPU', 'cpu/percenttotal': 'CPU с дочерними процессами',
    'memory/percent': 'Память', 'memory/percenttotal': 'Память с дочерними процессами',
    'memory/kilobyte': 'Память', 'memory/kilobytetotal': 'Память с дочерними процессами',
    'load/avg01': 'Нагрузка · 1 мин', 'load/avg05': 'Нагрузка · 5 мин',
    'load/avg15': 'Нагрузка · 15 мин', 'program/status': 'Код завершения',
    'program/output': 'Вывод проверки', 'port/hostname': 'Хост',
    'port/portnumber': 'Порт', 'port/responsetime': 'Время ответа',
    'port/protocol': 'Протокол', 'size': 'Размер (байты)',
    'mode': 'Режим мониторинга', 'pendingaction': 'Ожидающее действие',
    'collected_sec': 'Время проверки (Unix)', 'collected_usec': 'Микросекунды',
}


def field_value(key, value):
    if key == 'uptime':
        try:
            minutes = int(value) // 60
            days, minutes = divmod(minutes, 1440)
            hours, minutes = divmod(minutes, 60)
            return '{} д {} ч {} мин'.format(days, hours, minutes)
        except ValueError:
            return value
    if key.endswith(('percent', 'percenttotal')):
        return value + ' %'
    if key.endswith(('kilobyte', 'kilobytetotal')):
        try:
            return '{:.1f} МиБ'.format(float(value) / 1024)
        except ValueError:
            return value
    if key.endswith('responsetime'):
        return value + ' с'
    return value


def status(name):
    root = ET.fromstring(request('/_status?format=xml'))
    for service in root.findall('.//service'):
        if service.findtext('name') != name:
            continue
        icon, label = state({'monitor': service.findtext('monitor', '?'),
                             'status': service.findtext('status', '?')})
        lines = ['🖥 MONIT · Служба', '', name, icon + ' ' + label, '', '📊 Показатели']

        def fields(element, prefix=''):
            for child in element:
                key = prefix + child.tag
                if len(child):
                    fields(child, key + '/')
                elif child.text and key not in ('name', 'status', 'monitor'):
                    value = field_value(key, child.text.strip())
                    lines.append('{}: {}'.format(LABELS.get(key, key.replace('/', ' · ')), value))

        fields(service)
        lines.extend(['', 'Все службы: /summary'])
        return '\n'.join(lines)
    return '🔎 Служба не найдена\n\nСписок доступных: /services'
