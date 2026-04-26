<?php
declare(strict_types=1);

session_start();

function loadEnvFile(string $path): void
{
    if (!is_file($path) || !is_readable($path)) {
        return;
    }
    $lines = file($path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
    if ($lines === false) {
        return;
    }
    foreach ($lines as $line) {
        $trimmed = trim($line);
        if ($trimmed === '' || str_starts_with($trimmed, '#')) {
            continue;
        }
        $parts = explode('=', $trimmed, 2);
        if (count($parts) !== 2) {
            continue;
        }
        $key = trim($parts[0]);
        $value = trim($parts[1]);
        $value = trim($value, "\"'");
        if ($key === '') {
            continue;
        }
        putenv($key . '=' . $value);
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;
    }
}

function envValue(string $key, string $default = ''): string
{
    $value = getenv($key);
    return $value === false ? $default : $value;
}

loadEnvFile(__DIR__ . '/.env');

$authUser = envValue('MTPROTO_WEB_USER', 'admin');
$authPass = envValue('MTPROTO_WEB_PASS', 'change-me');
$serverHost = envValue('MTPROTO_SERVER_HOST', '127.0.0.1');

if (isset($_GET['logout'])) {
    $_SESSION = [];
    session_destroy();
    header('Location: /');
    exit;
}

$loginError = null;
if (($_SESSION['mtproto_auth'] ?? false) !== true) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && ($_POST['action'] ?? '') === 'login') {
        $providedUser = trim((string) ($_POST['login'] ?? ''));
        $providedPass = (string) ($_POST['password'] ?? '');
        if ($providedUser === $authUser && $providedPass === $authPass) {
            $_SESSION['mtproto_auth'] = true;
            header('Location: /');
            exit;
        }
        $loginError = 'Неверный логин или пароль.';
    }
    ?>
    <!DOCTYPE html>
    <html lang="ru">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Вход в MTProto</title>
        <style>
            :root {
                --bg: #0b1220;
                --panel: #121b2e;
                --panel-soft: #18243c;
                --line: rgba(255,255,255,.1);
                --text: #eef2ff;
                --muted: #99a4bd;
                --accent: #0fa487;
                --danger: #f45b69;
            }
            * { box-sizing: border-box; }
            body {
                margin: 0;
                min-height: 100vh;
                display: grid;
                place-items: center;
                font-family: system-ui, -apple-system, BlinkMacSystemFont, "Vazirmatn", "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif;
                color: var(--text);
                background:
                    radial-gradient(circle at top right, rgba(84,210,255,.12), transparent 22%),
                    linear-gradient(160deg, #09101c, var(--bg));
            }
            .login-card {
                width: min(420px, calc(100% - 24px));
                padding: 28px;
                border: 1px solid var(--line);
                border-radius: 22px;
                background: var(--panel);
            }
            h1 {
                margin: 0 0 10px;
                font-size: 24px;
                font-weight: 700;
            }
            p {
                margin: 0 0 18px;
                color: var(--muted);
            }
            .field {
                display: grid;
                gap: 8px;
                margin-bottom: 14px;
            }
            input {
                width: 100%;
                padding: 12px 14px;
                border: 1px solid var(--line);
                border-radius: 14px;
                background: var(--panel-soft);
                color: var(--text);
            }
            button {
                border: 0;
                border-radius: 14px;
                padding: 11px 16px;
                color: #effffc;
                background: var(--accent);
                font-weight: 600;
                cursor: pointer;
                width: 100%;
            }
            .error {
                margin-bottom: 14px;
                padding: 12px 14px;
                border-radius: 14px;
                font-weight: 600;
                background: rgba(244,91,105,.14);
                color: #ff9aa3;
            }
        </style>
    </head>
    <body>
        <main class="login-card">
            <h1>MTProto</h1>
            <p>Войдите с теми же данными, что и в 3x-ui.</p>
            <?php if ($loginError !== null): ?>
                <div class="error"><?php echo htmlspecialchars($loginError, ENT_QUOTES, 'UTF-8'); ?></div>
            <?php endif; ?>
            <form method="post">
                <input type="hidden" name="action" value="login">
                <div class="field">
                    <label for="login">Логин</label>
                    <input id="login" name="login" autocomplete="username" required>
                </div>
                <div class="field">
                    <label for="password">Пароль</label>
                    <input id="password" name="password" type="password" autocomplete="current-password" required>
                </div>
                <button type="submit">Войти</button>
            </form>
        </main>
    </body>
    </html>
    <?php
    exit;
}

function runShell(string $command): array
{
    $output = [];
    $exitCode = 0;
    exec($command . ' 2>&1', $output, $exitCode);
    return [
        'output' => implode("\n", $output),
        'exit_code' => $exitCode,
    ];
}

function formatBytes(int $bytes): string
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];
    $value = (float) $bytes;
    $unit = 0;
    while ($value >= 1024 && $unit < count($units) - 1) {
        $value /= 1024;
        $unit++;
    }
    if ($unit === 0) {
        return (string) ((int) $value) . ' ' . $units[$unit];
    }
    return number_format($value, 2, '.', '') . ' ' . $units[$unit];
}

function getTrafficStats(): array
{
    $stats = [];
    $raw = shell_exec('/usr/local/bin/mtproto-traffic report-tsv 2>/dev/null') ?? '';
    foreach (preg_split('/\r\n|\r|\n/', trim($raw)) as $line) {
        if ($line === '') {
            continue;
        }
        $parts = explode("\t", $line);
        if (count($parts) < 5) {
            continue;
        }
        [$user, $port, $inBytes, $outBytes, $totalBytes] = $parts;
        $stats[$user] = [
            'port' => $port,
            'in_bytes' => (int) $inBytes,
            'out_bytes' => (int) $outBytes,
            'total_bytes' => (int) $totalBytes,
        ];
    }
    return $stats;
}

function getMonthlyTrafficStats(): array
{
    $stats = [];
    $raw = shell_exec('/usr/local/bin/mtproto-traffic report-month-tsv 2>/dev/null') ?? '';
    foreach (preg_split('/\r\n|\r|\n/', trim($raw)) as $line) {
        if ($line === '') {
            continue;
        }
        $parts = explode("\t", $line);
        if (count($parts) < 5) {
            continue;
        }
        [$user, $port, $inBytes, $outBytes, $totalBytes] = $parts;
        $stats[$user] = [
            'port' => $port,
            'in_bytes' => (int) $inBytes,
            'out_bytes' => (int) $outBytes,
            'total_bytes' => (int) $totalBytes,
        ];
    }
    return $stats;
}

function getPortConnectionCounts(): array
{
    $counts = [];
    $raw = shell_exec('ss -Htan state established 2>/dev/null') ?? '';
    foreach (preg_split('/\r\n|\r|\n/', trim($raw)) as $line) {
        if ($line === '') {
            continue;
        }
        $parts = preg_split('/\s+/', trim($line));
        if (count($parts) < 4) {
            continue;
        }
        $endpoints = [$parts[count($parts) - 2], $parts[count($parts) - 1]];
        foreach ($endpoints as $endpoint) {
            if (preg_match('/:(\d+)$/', $endpoint, $match)) {
                $port = $match[1];
                $counts[$port] = ($counts[$port] ?? 0) + 1;
            }
        }
    }
    return $counts;
}

function getUserConfig(string $userName): ?array
{
    $configPath = '/etc/mtg-' . $userName . '.toml';
    if (!is_file($configPath)) {
        return null;
    }

    $content = (string) file_get_contents($configPath);
    preg_match('/bind-to\s*=\s*"0\.0\.0\.0:(\d+)"/', $content, $portMatch);
    preg_match('/secret\s*=\s*"([^"]+)"/', $content, $secretMatch);

    return [
        'config_path' => $configPath,
        'port' => $portMatch[1] ?? '',
        'secret' => $secretMatch[1] ?? '',
    ];
}

function serviceState(string $service): array
{
    $active = trim(shell_exec('systemctl is-active ' . escapeshellarg($service) . ' 2>/dev/null || true') ?? '');
    $enabled = trim(shell_exec('systemctl is-enabled ' . escapeshellarg($service) . ' 2>/dev/null || true') ?? '');
    return [
        'active' => $active,
        'enabled' => $enabled,
    ];
}

function healthCheck(string $label, string $status, string $details): array
{
    return [
        'label' => $label,
        'status' => $status,
        'details' => $details,
    ];
}

function getHealthChecks(array $users): array
{
    $checks = [];

    $checks[] = is_executable('/usr/local/bin/mtg')
        ? healthCheck('MTProto binary', 'ok', '/usr/local/bin/mtg найден и исполняемый')
        : healthCheck('MTProto binary', 'error', 'Не найден исполняемый /usr/local/bin/mtg');

    $checks[] = is_executable('/usr/local/bin/mtproto-traffic')
        ? healthCheck('Мониторинг трафика', 'ok', '/usr/local/bin/mtproto-traffic найден и исполняемый')
        : healthCheck('Мониторинг трафика', 'error', 'Не найден исполняемый /usr/local/bin/mtproto-traffic');

    $timer = serviceState('mtproto-traffic-collect.timer');
    $checks[] = ($timer['active'] === 'active' && $timer['enabled'] === 'enabled')
        ? healthCheck('Таймер сбора', 'ok', 'collect timer активен и включен в автозапуск')
        : healthCheck('Таймер сбора', 'error', 'mtproto-traffic-collect.timer: active=' . ($timer['active'] ?: 'unknown') . ', enabled=' . ($timer['enabled'] ?: 'unknown'));

    $sync = serviceState('mtproto-traffic-sync.service');
    $checks[] = ($sync['enabled'] === 'enabled')
        ? healthCheck('Sync при старте', 'ok', 'mtproto-traffic-sync.service включен в автозапуск')
        : healthCheck('Sync при старте', 'warning', 'mtproto-traffic-sync.service не включен в автозапуск: enabled=' . ($sync['enabled'] ?: 'unknown'));

    $iptablesChains = runShell('iptables -S MTPROTO_TRAFFIC_IN >/dev/null && iptables -S MTPROTO_TRAFFIC_OUT >/dev/null');
    $rulesRaw = shell_exec('iptables-save 2>/dev/null | grep -c "mtproto:" || true') ?? '0';
    $rulesCount = (int) trim($rulesRaw);
    if ($iptablesChains['exit_code'] === 0 && $rulesCount > 0) {
        $checks[] = healthCheck('Правила iptables', 'ok', 'Цепочки есть, правил учета: ' . $rulesCount);
    } elseif ($iptablesChains['exit_code'] === 0) {
        $checks[] = healthCheck('Правила iptables', 'warning', 'Цепочки есть, но правила пользователей не найдены');
    } else {
        $checks[] = healthCheck('Правила iptables', 'error', 'Нет цепочек MTPROTO_TRAFFIC_IN / MTPROTO_TRAFFIC_OUT');
    }

    $web = serviceState('mtproto-web.service');
    $checks[] = ($web['active'] === 'active')
        ? healthCheck('Web UI backend', 'ok', 'mtproto-web.service активен')
        : healthCheck('Web UI backend', 'warning', 'mtproto-web.service: active=' . ($web['active'] ?: 'unknown'));

    $tls = serviceState('mtproto-web-tls.service');
    $checks[] = ($tls['active'] === 'active')
        ? healthCheck('HTTPS wrapper', 'ok', 'mtproto-web-tls.service активен')
        : healthCheck('HTTPS wrapper', 'warning', 'mtproto-web-tls.service: active=' . ($tls['active'] ?: 'unknown'));

    return $checks;
}

function listUsers(string $serverHost): array
{
    $rows = [];
    $trafficStats = getTrafficStats();
    $monthlyTrafficStats = getMonthlyTrafficStats();
    $connectionCounts = getPortConnectionCounts();
    foreach (glob('/etc/mtg-*.toml') as $config) {
        $user = basename($config, '.toml');
        $user = preg_replace('/^mtg-/', '', $user) ?? $user;
        $content = @file_get_contents($config) ?: '';
        preg_match('/bind-to\s*=\s*"0\.0\.0\.0:(\d+)"/', $content, $portMatch);
        preg_match('/secret\s*=\s*"([^"]+)"/', $content, $secretMatch);
        $port = $portMatch[1] ?? '?';
        $secretHex = $secretMatch[1] ?? '';
        $secretBase64 = trim(shell_exec('/usr/local/bin/mtg access ' . escapeshellarg($config) . " | sed -n 's/.*\"base64\": \"\\([^\"]*\\)\".*/\\1/p'") ?? '');
        $service = 'mtg-' . $user;
        $active = trim(shell_exec('systemctl is-active ' . escapeshellarg($service) . ' 2>/dev/null || true') ?? '');
        $enabled = trim(shell_exec('systemctl is-enabled ' . escapeshellarg($service) . ' 2>/dev/null || true') ?? '');
        $tgUrl = '';
        if ($port !== '?' && $secretBase64 !== '') {
            $tgUrl = 'tg://proxy?server=' . $serverHost . '&port=' . $port . '&secret=' . $secretBase64;
        }
        $traffic = $trafficStats[$user] ?? [
            'in_bytes' => 0,
            'out_bytes' => 0,
            'total_bytes' => 0,
        ];
        $monthlyTraffic = $monthlyTrafficStats[$user] ?? [
            'in_bytes' => 0,
            'out_bytes' => 0,
            'total_bytes' => 0,
        ];
        $onlineConnections = ($port !== '?' && isset($connectionCounts[$port])) ? (int) $connectionCounts[$port] : 0;
        $rows[] = [
            'user' => $user,
            'port' => $port,
            'active' => $active,
            'enabled' => $enabled,
            'secret_hex' => $secretHex,
            'secret_base64' => $secretBase64,
            'tg_url' => $tgUrl,
            'in_bytes' => $traffic['in_bytes'],
            'out_bytes' => $traffic['out_bytes'],
            'total_bytes' => $traffic['total_bytes'],
            'month_in_bytes' => $monthlyTraffic['in_bytes'],
            'month_out_bytes' => $monthlyTraffic['out_bytes'],
            'month_total_bytes' => $monthlyTraffic['total_bytes'],
            'online_connections' => $onlineConnections,
        ];
    }
    usort($rows, static fn(array $a, array $b): int => strcmp($a['user'], $b['user']));
    return $rows;
}

$flash = null;
$details = null;
$editTarget = null;
$modalMode = null;
$editValues = [
    'original_user' => '',
    'user_name' => '',
    'port' => '',
    'hostname_fqdn' => '',
];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    $userName = trim((string) ($_POST['user_name'] ?? ''));

    if ($action === 'add') {
        $modalMode = 'create';
        $port = trim((string) ($_POST['port'] ?? ''));
        $hostname = trim((string) ($_POST['hostname_fqdn'] ?? ''));

        if ($userName === '' || $port === '') {
            $flash = ['type' => 'error', 'text' => 'Имя пользователя и порт обязательны.'];
        } elseif (!preg_match('/^\d+$/', $port)) {
            $flash = ['type' => 'error', 'text' => 'Порт должен быть числом.'];
        } else {
            if ($hostname === '') {
                $hostname = trim(shell_exec('hostname -f') ?? '');
            }

            $secret = trim(shell_exec('/usr/local/bin/mtg generate-secret --hex ' . escapeshellarg($hostname)) ?? '');
            if ($secret === '') {
                $details = ['output' => 'Не удалось сгенерировать secret.', 'exit_code' => 1];
            } else {
                $configPath = '/etc/mtg-' . $userName . '.toml';
                $serviceName = 'mtg-' . $userName;
                $servicePath = '/etc/systemd/system/' . $serviceName . '.service';

                file_put_contents(
                    $configPath,
                    "secret = \"{$secret}\"\n" .
                    "bind-to = \"0.0.0.0:{$port}\"\n" .
                    "prefer-ip = \"prefer-ipv4\"\n"
                );

                file_put_contents(
                    $servicePath,
                    "[Unit]\n" .
                    "Description=mtg - MTProto proxy server ({$userName})\n" .
                    "Documentation=https://github.com/9seconds/mtg\n" .
                    "After=network.target\n" .
                    "Wants=network.target\n\n" .
                    "[Service]\n" .
                    "ExecStart=/usr/local/bin/mtg run {$configPath}\n" .
                    "Restart=always\n" .
                    "RestartSec=3\n" .
                    "DynamicUser=true\n" .
                    "AmbientCapabilities=CAP_NET_BIND_SERVICE\n" .
                    "LimitNOFILE=65536\n\n" .
                    "[Install]\n" .
                    "WantedBy=multi-user.target\n"
                );

                $details = runShell(
                    'systemctl daemon-reload && ' .
                    'systemctl enable --now ' . escapeshellarg($serviceName) . ' && ' .
                    'if [ -x /usr/local/bin/mtproto-traffic ]; then /usr/local/bin/mtproto-traffic sync && /usr/local/bin/mtproto-traffic collect; fi && ' .
                    '/usr/local/bin/mtg access ' . escapeshellarg($configPath)
                );
            }

            $flash = [
                'type' => ($details['exit_code'] ?? 1) === 0 ? 'success' : 'error',
                'text' => ($details['exit_code'] ?? 1) === 0 ? 'Клиент создан.' : 'Не удалось создать клиента.',
            ];
            if (($details['exit_code'] ?? 1) === 0) {
                $modalMode = null;
            }
        }
    }

    if ($action === 'remove') {
        if ($userName === '') {
            $flash = ['type' => 'error', 'text' => 'Имя пользователя обязательно.'];
        } else {
            $service = 'mtg-' . $userName;
            $details = runShell(
                'if [ -x /usr/local/bin/mtproto-traffic ]; then /usr/local/bin/mtproto-traffic collect >/dev/null 2>&1 || true; fi; ' .
                'systemctl stop ' . escapeshellarg($service) . ' >/dev/null 2>&1 || true; ' .
                'systemctl disable ' . escapeshellarg($service) . ' >/dev/null 2>&1 || true; ' .
                'rm -f ' . escapeshellarg('/etc/systemd/system/' . $service . '.service') . '; ' .
                'rm -f ' . escapeshellarg('/etc/mtg-' . $userName . '.toml') . '; ' .
                'systemctl daemon-reload; ' .
                'if [ -x /usr/local/bin/mtproto-traffic ]; then /usr/local/bin/mtproto-traffic forget ' . escapeshellarg($userName) . ' >/dev/null 2>&1 || true; /usr/local/bin/mtproto-traffic sync >/dev/null 2>&1 || true; /usr/local/bin/mtproto-traffic collect >/dev/null 2>&1 || true; fi; ' .
                'echo Удален ' . escapeshellarg($userName)
            );
            $flash = [
                'type' => $details['exit_code'] === 0 ? 'success' : 'error',
                'text' => $details['exit_code'] === 0 ? 'Клиент удален.' : 'Не удалось удалить клиента.',
            ];
        }
    }

    if ($action === 'toggle') {
        if ($userName === '') {
            $flash = ['type' => 'error', 'text' => 'Имя пользователя обязательно.'];
        } else {
            $service = 'mtg-' . $userName;
            $isActive = trim(shell_exec('systemctl is-active ' . escapeshellarg($service) . ' 2>/dev/null || true') ?? '') === 'active';
            $isEnabled = trim(shell_exec('systemctl is-enabled ' . escapeshellarg($service) . ' 2>/dev/null || true') ?? '') === 'enabled';
            if ($isActive || $isEnabled) {
                $details = runShell(
                    'systemctl stop ' . escapeshellarg($service) . ' && ' .
                    'systemctl disable ' . escapeshellarg($service)
                );
                $flash = [
                    'type' => $details['exit_code'] === 0 ? 'success' : 'error',
                    'text' => $details['exit_code'] === 0 ? 'Клиент выключен.' : 'Не удалось выключить клиента.',
                ];
            } else {
                $details = runShell(
                    'systemctl enable --now ' . escapeshellarg($service)
                );
                $flash = [
                    'type' => $details['exit_code'] === 0 ? 'success' : 'error',
                    'text' => $details['exit_code'] === 0 ? 'Клиент включен.' : 'Не удалось включить клиента.',
                ];
            }
        }
    }

    if ($action === 'info') {
        if ($userName === '') {
            $flash = ['type' => 'error', 'text' => 'Имя пользователя обязательно.'];
        } else {
            $details = runShell(
                '/usr/local/bin/mtg access ' . escapeshellarg('/etc/mtg-' . $userName . '.toml') .
                ' && printf "\n\n--- systemctl ---\n\n" && systemctl status ' . escapeshellarg('mtg-' . $userName) . ' --no-pager -l'
            );
            $flash = [
                'type' => $details['exit_code'] === 0 ? 'success' : 'error',
                'text' => $details['exit_code'] === 0 ? 'Информация загружена для ' . $userName . '.' : 'Не удалось получить информацию.',
            ];
        }
    }

    if ($action === 'edit_load') {
        if ($userName !== '') {
            $config = getUserConfig($userName);
            if ($config !== null) {
                $modalMode = 'edit';
                $editTarget = $userName;
                $editValues = [
                    'original_user' => $userName,
                    'user_name' => $userName,
                    'port' => $config['port'],
                    'hostname_fqdn' => '',
                ];
                $flash = ['type' => 'success', 'text' => 'Режим редактирования: ' . $userName . '.'];
            }
        }
    }

    if ($action === 'edit_save') {
        $modalMode = 'edit';
        $originalUser = trim((string) ($_POST['original_user'] ?? ''));
        $newUserName = trim((string) ($_POST['user_name'] ?? ''));
        $port = trim((string) ($_POST['port'] ?? ''));
        $hostname = trim((string) ($_POST['hostname_fqdn'] ?? ''));

        $editTarget = $originalUser !== '' ? $originalUser : $newUserName;
        $editValues = [
            'original_user' => $originalUser,
            'user_name' => $newUserName,
            'port' => $port,
            'hostname_fqdn' => $hostname,
        ];

        if ($originalUser === '' || $newUserName === '' || $port === '') {
            $flash = ['type' => 'error', 'text' => 'Для редактирования нужны имя и порт.'];
        } elseif (!preg_match('/^\d+$/', $port)) {
            $flash = ['type' => 'error', 'text' => 'Порт должен быть числом.'];
        } else {
            $current = getUserConfig($originalUser);
            if ($current === null) {
                $flash = ['type' => 'error', 'text' => 'Клиент для редактирования не найден.'];
            } else {
                $oldService = 'mtg-' . $originalUser;
                $newService = 'mtg-' . $newUserName;
                $secret = $current['secret'];
                if ($hostname !== '') {
                    $generatedSecret = trim(shell_exec('/usr/local/bin/mtg generate-secret --hex ' . escapeshellarg($hostname)) ?? '');
                    if ($generatedSecret !== '') {
                        $secret = $generatedSecret;
                    }
                }

                $newConfigPath = '/etc/mtg-' . $newUserName . '.toml';
                $newServicePath = '/etc/systemd/system/' . $newService . '.service';

                file_put_contents(
                    $newConfigPath,
                    "secret = \"{$secret}\"\n" .
                    "bind-to = \"0.0.0.0:{$port}\"\n" .
                    "prefer-ip = \"prefer-ipv4\"\n"
                );

                file_put_contents(
                    $newServicePath,
                    "[Unit]\n" .
                    "Description=mtg - MTProto proxy server ({$newUserName})\n" .
                    "Documentation=https://github.com/9seconds/mtg\n" .
                    "After=network.target\n" .
                    "Wants=network.target\n\n" .
                    "[Service]\n" .
                    "ExecStart=/usr/local/bin/mtg run {$newConfigPath}\n" .
                    "Restart=always\n" .
                    "RestartSec=3\n" .
                    "DynamicUser=true\n" .
                    "AmbientCapabilities=CAP_NET_BIND_SERVICE\n" .
                    "LimitNOFILE=65536\n\n" .
                    "[Install]\n" .
                    "WantedBy=multi-user.target\n"
                );

                $commands = [];
                $commands[] = 'systemctl stop ' . escapeshellarg($oldService) . ' >/dev/null 2>&1 || true';
                $commands[] = 'systemctl disable ' . escapeshellarg($oldService) . ' >/dev/null 2>&1 || true';
                if ($originalUser !== $newUserName) {
                    $commands[] = 'rm -f ' . escapeshellarg('/etc/mtg-' . $originalUser . '.toml');
                    $commands[] = 'rm -f ' . escapeshellarg('/etc/systemd/system/' . $oldService . '.service');
                }
                $commands[] = 'systemctl daemon-reload';
                $commands[] = 'systemctl enable --now ' . escapeshellarg($newService);
                $commands[] = 'if [ -x /usr/local/bin/mtproto-traffic ]; then /usr/local/bin/mtproto-traffic sync >/dev/null 2>&1 || true; /usr/local/bin/mtproto-traffic collect >/dev/null 2>&1 || true; fi';
                $commands[] = '/usr/local/bin/mtg access ' . escapeshellarg($newConfigPath);

                $details = runShell(implode(' && ', $commands));
                $flash = [
                    'type' => $details['exit_code'] === 0 ? 'success' : 'error',
                    'text' => $details['exit_code'] === 0 ? 'Клиент обновлен.' : 'Не удалось обновить клиента.',
                ];
                if ($details['exit_code'] === 0) {
                    $editTarget = null;
                    $modalMode = null;
                    $editValues = [
                        'original_user' => '',
                        'user_name' => '',
                        'port' => '',
                        'hostname_fqdn' => '',
                    ];
                }
            }
        }
    }
}

$users = listUsers($serverHost);
$totalUsers = count($users);
$activeUsers = count(array_filter($users, static fn(array $user): bool => ($user['online_connections'] ?? 0) > 0));
$activeUserNames = array_values(array_map(
    static fn(array $user): string => $user['user'],
    array_filter($users, static fn(array $user): bool => ($user['online_connections'] ?? 0) > 0)
));
$totalConnections = array_sum(array_column($users, 'online_connections'));
$totalTraffic = array_sum(array_column($users, 'total_bytes'));
$totalMonthlyTraffic = array_sum(array_column($users, 'month_total_bytes'));
$totalInbound = array_sum(array_column($users, 'in_bytes'));
$totalOutbound = array_sum(array_column($users, 'out_bytes'));
$healthChecks = getHealthChecks($users);
$healthErrors = count(array_filter($healthChecks, static fn(array $check): bool => $check['status'] === 'error'));
$healthWarnings = count(array_filter($healthChecks, static fn(array $check): bool => $check['status'] === 'warning'));
$healthOk = count(array_filter($healthChecks, static fn(array $check): bool => $check['status'] === 'ok'));
$healthSummaryStatus = $healthErrors > 0 ? 'error' : ($healthWarnings > 0 ? 'warning' : 'ok');
$healthSummaryText = $healthErrors > 0
    ? 'Есть ошибки'
    : ($healthWarnings > 0 ? 'Есть предупреждения' : 'Все в порядке');
$nextPort = 8443;
foreach ($users as $user) {
    if (is_numeric($user['port'])) {
        $nextPort = max($nextPort, ((int) $user['port']) + 1);
    }
}

if ($editTarget !== null && $editValues['original_user'] === '') {
    foreach ($users as $user) {
        if ($user['user'] === $editTarget) {
            $editValues = [
                'original_user' => $user['user'],
                'user_name' => $user['user'],
                'port' => (string) $user['port'],
                'hostname_fqdn' => '',
            ];
            break;
        }
    }
}
$isEditModal = $modalMode === 'edit';
$isCreateModal = $modalMode === 'create' || ($modalMode === null && $editTarget === null);
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>MTProto Admin</title>
    <style>
        :root {
            --bg: #081120;
            --panel: #111b30;
            --panel-top: #131f36;
            --panel-soft: #1a2740;
            --panel-hover: rgba(255, 255, 255, 0.02);
            --line: rgba(126, 145, 179, 0.22);
            --text: #ecf2ff;
            --muted: #9aabc9;
            --accent: #08a08a;
            --accent-strong: #0db39b;
            --accent-soft: rgba(8, 160, 138, 0.18);
            --purple: #a34394;
            --purple-soft: rgba(163, 67, 148, 0.18);
            --danger: #f36d92;
            --danger-soft: rgba(243, 109, 146, 0.18);
            --shadow: 0 20px 50px rgba(0, 0, 0, 0.34);
        }
        * { box-sizing: border-box; }
        body {
            margin: 0;
            min-height: 100vh;
            font-family: system-ui, -apple-system, BlinkMacSystemFont, "Vazirmatn", "Segoe UI", Roboto, Oxygen, Ubuntu, Cantarell, "Open Sans", "Helvetica Neue", sans-serif;
            font-size: 13px;
            color: var(--text);
            background:
                radial-gradient(circle at top right, rgba(70, 131, 255, 0.12), transparent 20%),
                radial-gradient(circle at top left, rgba(8, 160, 138, 0.08), transparent 20%),
                linear-gradient(180deg, #07101d, var(--bg));
        }
        button, input {
            font: inherit;
        }
        .page {
            width: min(1380px, calc(100% - 28px));
            margin: 0 auto;
            padding: 22px 0 38px;
        }
        .topbar, .panel {
            border: 1px solid var(--line);
            border-radius: 24px;
            background: rgba(17, 27, 48, 0.94);
            box-shadow: var(--shadow);
        }
        .topbar {
            display: flex;
            justify-content: space-between;
            align-items: center;
            gap: 18px;
            padding: 18px 22px;
            margin-bottom: 18px;
        }
        .brand {
            display: flex;
            align-items: center;
            gap: 14px;
        }
        .brand-mark {
            width: 44px;
            height: 44px;
            display: grid;
            place-items: center;
            border-radius: 14px;
            background: linear-gradient(135deg, rgba(8, 160, 138, 0.24), rgba(70, 131, 255, 0.18));
            color: #dbfffa;
        }
        .brand h1 {
            margin: 0;
            font-size: 19px;
            font-weight: 700;
        }
        .brand p {
            margin: 4px 0 0;
            color: var(--muted);
            font-size: 12px;
        }
        .topbar-actions {
            display: flex;
            gap: 10px;
        }
        .overview-strip {
            display: grid;
            grid-template-columns: repeat(6, minmax(0, 1fr));
            gap: 24px;
            padding: 18px 22px;
            margin-bottom: 18px;
            border: 1px solid var(--line);
            border-radius: 26px;
            background: rgba(19, 31, 54, 0.96);
            box-shadow: var(--shadow);
        }
        .overview-item {
            min-height: 72px;
            display: flex;
            flex-direction: column;
            justify-content: center;
            gap: 8px;
        }
        .overview-label {
            color: var(--muted);
            font-size: 12px;
            font-weight: 600;
        }
        .overview-value {
            display: flex;
            align-items: center;
            gap: 8px;
            font-size: 18px;
            font-weight: 600;
            line-height: 1.2;
            color: #eff4ff;
        }
        .overview-value svg {
            width: 18px;
            height: 18px;
            color: #cfd8ea;
            flex: 0 0 auto;
        }
        .overview-badges {
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        .overview-pill {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 28px;
            height: 28px;
            padding: 0 10px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 600;
            border: 1px solid transparent;
        }
        .overview-pill.green {
            color: #6dffd9;
            background: rgba(8, 160, 138, 0.14);
            border-color: rgba(8, 160, 138, 0.28);
        }
        .overview-pill.blue {
            color: #8ab4ff;
            background: rgba(70, 131, 255, 0.12);
            border-color: rgba(70, 131, 255, 0.28);
        }
        .overview-hover {
            position: relative;
            display: inline-flex;
        }
        .overview-popover {
            position: absolute;
            top: calc(100% + 12px);
            right: -8px;
            min-width: 220px;
            padding: 0;
            border: 1px solid rgba(102, 123, 161, 0.3);
            border-radius: 24px;
            background: #34425d;
            color: #f0f5ff;
            box-shadow: 0 24px 48px rgba(0, 0, 0, 0.35);
            opacity: 0;
            transform: translateY(8px);
            pointer-events: none;
            transition: opacity .18s ease, transform .18s ease;
            z-index: 12;
        }
        .overview-popover::before {
            content: "";
            position: absolute;
            top: -8px;
            right: 24px;
            width: 16px;
            height: 16px;
            background: #34425d;
            border-left: 1px solid rgba(102, 123, 161, 0.3);
            border-top: 1px solid rgba(102, 123, 161, 0.3);
            transform: rotate(45deg);
        }
        .overview-hover:hover .overview-popover,
        .overview-hover:focus-within .overview-popover {
            opacity: 1;
            transform: translateY(0);
            pointer-events: auto;
        }
        .overview-popover-title {
            padding: 14px 18px 12px;
            font-size: 15px;
            font-weight: 700;
            border-bottom: 1px solid rgba(102, 123, 161, 0.24);
        }
        .overview-popover-list {
            padding: 14px 18px 16px;
            display: grid;
            gap: 10px;
            font-size: 13px;
        }
        .overview-popover-empty {
            color: #d6deed;
        }
        .health-panel {
            margin-top: 20px;
            border: 1px solid var(--line);
            border-radius: 24px;
            background: rgba(17, 27, 48, 0.94);
            box-shadow: var(--shadow);
            overflow: hidden;
        }
        .health-head {
            display: flex;
            align-items: center;
            justify-content: space-between;
            gap: 16px;
            padding: 16px 20px;
            border-bottom: 1px solid var(--line);
        }
        .health-head h2 {
            margin: 0;
            font-size: 16px;
            font-weight: 700;
        }
        .health-head p {
            margin: 4px 0 0;
            color: var(--muted);
            font-size: 12px;
        }
        .health-summary {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            padding: 7px 11px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 600;
            white-space: nowrap;
            border: 1px solid transparent;
        }
        .health-summary.ok {
            color: #6dffd9;
            background: rgba(8, 160, 138, 0.12);
            border-color: rgba(8, 160, 138, 0.28);
        }
        .health-summary.warning {
            color: #ffd58a;
            background: rgba(245, 178, 70, 0.12);
            border-color: rgba(245, 178, 70, 0.28);
        }
        .health-summary.error {
            color: #ffabc0;
            background: rgba(243, 109, 146, 0.12);
            border-color: rgba(243, 109, 146, 0.28);
        }
        .health-table-wrap {
            overflow-x: auto;
        }
        .health-table {
            width: 100%;
            border-collapse: collapse;
        }
        .health-table th,
        .health-table td {
            padding: 13px 16px;
            border-bottom: 1px solid var(--line);
            text-align: left;
            vertical-align: middle;
            font-size: 13px;
        }
        .health-table th {
            color: #e8efff;
            background: rgba(6, 13, 25, 0.58);
            font-weight: 600;
        }
        .health-table tr:last-child td {
            border-bottom: 0;
        }
        .health-name {
            min-width: 190px;
            font-weight: 600;
        }
        .health-status {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            min-width: 58px;
            height: 24px;
            padding: 0 9px;
            border-radius: 999px;
            font-size: 11px;
            font-weight: 700;
            border: 1px solid transparent;
        }
        .health-status.ok {
            color: #6dffd9;
            background: rgba(8, 160, 138, 0.12);
            border-color: rgba(8, 160, 138, 0.26);
        }
        .health-status.warning {
            color: #ffd58a;
            background: rgba(245, 178, 70, 0.12);
            border-color: rgba(245, 178, 70, 0.26);
        }
        .health-status.error {
            color: #ffabc0;
            background: rgba(243, 109, 146, 0.12);
            border-color: rgba(243, 109, 146, 0.26);
        }
        .health-details {
            color: var(--muted);
            line-height: 1.45;
        }
        .panel-header {
            padding: 18px 22px;
            border-bottom: 1px solid var(--line);
            display: flex;
            justify-content: space-between;
            gap: 16px;
            align-items: center;
        }
        .panel-header h2 {
            margin: 0;
            font-size: 17px;
            font-weight: 700;
        }
        .panel-header p {
            margin: 4px 0 0;
            color: var(--muted);
            font-size: 12px;
        }
        .panel-body {
            padding: 18px 22px 22px;
        }
        .flash {
            margin-bottom: 16px;
            padding: 12px 14px;
            border-radius: 16px;
            font-weight: 700;
        }
        .flash.success {
            background: rgba(14, 181, 155, 0.14);
            color: #87ffe0;
        }
        .flash.error {
            background: rgba(243, 109, 146, 0.14);
            color: #ffabc0;
        }
        .table-wrap {
            overflow-x: auto;
            border: 1px solid var(--line);
            border-radius: 22px;
            background: #0b1527;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th, td {
            padding: 16px 18px;
            border-bottom: 1px solid var(--line);
            text-align: left;
            vertical-align: middle;
        }
        th {
            color: #c4d0e6;
            font-size: 14px;
            font-weight: 600;
            background: rgba(6, 13, 25, 0.7);
        }
        tbody tr:hover {
            background: var(--panel-hover);
        }
        tbody tr:last-child td {
            border-bottom: 0;
        }
        .menu-cell {
            width: 164px;
            min-width: 164px;
        }
        .switch-cell, .online-cell {
            width: 150px;
        }
        .client-cell {
            min-width: 300px;
        }
        .traffic-cell {
            min-width: 330px;
        }
        .direction-cell {
            min-width: 250px;
        }
        .menu-actions {
            display: flex;
            align-items: center;
            gap: 4px;
            flex-wrap: nowrap;
        }
        .icon-button {
            width: 28px;
            height: 28px;
            border: 0;
            padding: 0;
            border-radius: 8px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            background: transparent;
            color: #eaf1ff;
            cursor: pointer;
        }
        .icon-button svg {
            width: 19px;
            height: 19px;
        }
        .icon-button:hover {
            background: rgba(255,255,255,.06);
        }
        .icon-button.danger:hover {
            background: var(--danger-soft);
            color: #ffd7e3;
        }
        .switch-form {
            margin: 0;
        }
        .switch {
            position: relative;
            display: inline-block;
            width: 48px;
            height: 26px;
        }
        .switch input {
            opacity: 0;
            width: 0;
            height: 0;
            position: absolute;
        }
        .slider {
            position: absolute;
            inset: 0;
            background: rgba(255,255,255,.12);
            border: 1px solid rgba(255,255,255,.08);
            border-radius: 999px;
            transition: .2s ease;
            cursor: pointer;
        }
        .slider::before {
            content: "";
            position: absolute;
            width: 18px;
            height: 18px;
            left: 4px;
            top: 3px;
            border-radius: 50%;
            background: #fff;
            transition: .2s ease;
        }
        .switch input:checked + .slider {
            background: linear-gradient(180deg, var(--accent), var(--accent-strong));
            border-color: transparent;
        }
        .switch input:checked + .slider::before {
            transform: translateX(20px);
        }
        .badge {
            display: inline-flex;
            align-items: center;
            justify-content: center;
            padding: 6px 12px;
            border-radius: 999px;
            font-size: 14px;
            font-weight: 600;
            border: 1px solid transparent;
        }
        .badge.online {
            background: rgba(8, 160, 138, 0.14);
            color: #67ffd8;
            border-color: rgba(8, 160, 138, 0.24);
        }
        .badge.offline {
            background: transparent;
            color: #d3ddef;
            border-color: rgba(157, 171, 201, 0.28);
            box-shadow: inset 0 0 0 1px rgba(255, 255, 255, 0.02);
        }
        .client-name {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 14px;
            font-weight: 600;
            white-space: nowrap;
        }
        .client-dot {
            width: 8px;
            height: 8px;
            border-radius: 999px;
            background: var(--purple);
            box-shadow: 0 0 0 4px rgba(163, 67, 148, 0.08);
        }
        .chip {
            display: inline-flex;
            align-items: center;
            padding: 4px 9px;
            border-radius: 999px;
            font-size: 14px;
            color: #bfd1ff;
            background: rgba(70, 131, 255, 0.1);
            border: 1px solid rgba(70, 131, 255, 0.24);
        }
        .traffic-row {
            display: grid;
            grid-template-columns: 92px 220px;
            align-items: center;
            gap: 10px;
        }
        .traffic-total {
            font-weight: 600;
            font-size: 14px;
            white-space: nowrap;
        }
        .traffic-bar {
            width: 220px;
            height: 10px;
            border-radius: 999px;
            background: rgba(163, 67, 148, 0.2);
            overflow: hidden;
        }
        .traffic-bar span {
            display: block;
            height: 100%;
            border-radius: 999px;
            background: linear-gradient(90deg, #a34394, #be53ab);
        }
        .direction-row {
            display: inline-flex;
            align-items: center;
            gap: 8px;
            white-space: nowrap;
            color: #dce5f5;
            font-size: 14px;
            font-weight: 500;
        }
        .direction-row svg {
            width: 16px;
            height: 16px;
            color: #cfd8ea;
            flex: 0 0 auto;
        }
        .modal-backdrop {
            position: fixed;
            inset: 0;
            display: none;
            align-items: center;
            justify-content: center;
            padding: 18px;
            background: rgba(4, 10, 18, 0.72);
            backdrop-filter: blur(8px);
            z-index: 40;
        }
        .modal-backdrop.is-open {
            display: flex;
        }
        .modal-card {
            width: min(520px, 100%);
            border: 1px solid var(--line);
            border-radius: 22px;
            background: rgba(15, 23, 41, 0.96);
            box-shadow: var(--shadow);
            overflow: hidden;
        }
        .modal-head {
            padding: 16px 18px;
            border-bottom: 1px solid var(--line);
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 16px;
        }
        .modal-head h3 {
            margin: 0;
            font-size: 16px;
            font-weight: 700;
        }
        .modal-head p {
            margin: 5px 0 0;
            font-size: 11px;
            color: var(--muted);
        }
        .modal-body {
            padding: 18px;
        }
        .modal-close {
            width: 32px;
            height: 32px;
            border: 0;
            border-radius: 10px;
            background: rgba(255,255,255,.06);
            color: var(--text);
            cursor: pointer;
            flex: 0 0 auto;
        }
        .field {
            display: grid;
            gap: 8px;
            margin-bottom: 14px;
        }
        .field label {
            color: var(--muted);
            font-size: 11px;
            font-weight: 600;
        }
        .field input {
            width: 100%;
            padding: 12px 14px;
            border: 1px solid var(--line);
            border-radius: 14px;
            background: var(--panel-soft);
            color: var(--text);
            outline: none;
        }
        .field input:focus {
            border-color: rgba(8, 160, 138, 0.6);
            box-shadow: 0 0 0 3px rgba(8, 160, 138, 0.12);
        }
        .button-row {
            display: flex;
            align-items: center;
            gap: 10px;
            flex-wrap: wrap;
        }
        .button-primary,
        .button-secondary {
            border: 0;
            border-radius: 999px;
            padding: 10px 16px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
        }
        .button-primary {
            background: linear-gradient(180deg, var(--accent), var(--accent-strong));
            color: #effffc;
        }
        .button-secondary {
            background: rgba(255,255,255,.06);
            color: var(--text);
            border: 1px solid var(--line);
        }
        .compact-toggle.is-active {
            background: rgba(8, 160, 138, 0.16);
            border-color: rgba(8, 160, 138, 0.32);
            color: #ddfffa;
        }
        .button-secondary svg {
            width: 15px;
            height: 15px;
            margin-right: 7px;
            vertical-align: -3px;
        }
        body.compact .page {
            padding: 14px 0 24px;
        }
        body.compact .topbar {
            padding: 13px 16px;
            margin-bottom: 12px;
            border-radius: 20px;
        }
        body.compact .brand {
            gap: 10px;
        }
        body.compact .brand-mark {
            width: 36px;
            height: 36px;
            border-radius: 12px;
        }
        body.compact .brand h1 {
            font-size: 17px;
        }
        body.compact .brand p {
            font-size: 11px;
            margin-top: 2px;
        }
        body.compact .topbar-actions {
            gap: 8px;
        }
        body.compact .overview-strip {
            gap: 16px;
            padding: 13px 16px;
            margin-bottom: 12px;
            border-radius: 20px;
        }
        body.compact .overview-item {
            min-height: 58px;
            gap: 5px;
        }
        body.compact .overview-label {
            font-size: 11px;
        }
        body.compact .overview-value {
            font-size: 15px;
        }
        body.compact .panel-header {
            padding: 13px 16px;
        }
        body.compact .panel-header h2 {
            font-size: 15px;
        }
        body.compact .panel-body {
            padding: 12px 16px 16px;
        }
        body.compact th,
        body.compact td {
            padding: 12px 14px;
        }
        body.compact th {
            font-size: 13px;
        }
        body.compact .menu-cell {
            width: 142px;
            min-width: 142px;
        }
        body.compact .icon-button {
            width: 24px;
            height: 24px;
        }
        body.compact .icon-button svg {
            width: 17px;
            height: 17px;
        }
        body.compact .switch {
            width: 42px;
            height: 24px;
        }
        body.compact .slider::before {
            width: 16px;
            height: 16px;
            left: 4px;
            top: 3px;
        }
        body.compact .switch input:checked + .slider::before {
            transform: translateX(17px);
        }
        body.compact .badge,
        body.compact .chip,
        body.compact .client-name,
        body.compact .traffic-total,
        body.compact .direction-row {
            font-size: 13px;
        }
        body.compact .traffic-row {
            grid-template-columns: 84px 190px;
            gap: 8px;
        }
        body.compact .traffic-bar {
            width: 190px;
            height: 9px;
        }
        body.compact .command-card,
        body.compact .health-panel {
            margin-top: 14px;
            border-radius: 20px;
        }
        body.compact .command-head,
        body.compact .health-head {
            padding: 13px 16px;
        }
        body.compact pre {
            padding: 14px 16px;
            min-height: 120px;
        }
        .refresh-control {
            position: relative;
            display: inline-flex;
        }
        .refresh-group {
            display: inline-flex;
            overflow: hidden;
            border: 1px solid rgba(8, 160, 138, 0.5);
            border-radius: 999px;
            background: rgba(8, 160, 138, 0.08);
        }
        .refresh-button,
        .refresh-menu-button {
            width: 31px;
            height: 32px;
            flex: 0 0 31px;
            border: 0;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            background: transparent;
            color: #d9e7f8;
            cursor: pointer;
        }
        .refresh-button {
            border-right: 1px solid rgba(8, 160, 138, 0.4);
        }
        .refresh-button:hover,
        .refresh-menu-button:hover {
            background: rgba(8, 160, 138, 0.14);
        }
        .refresh-button svg,
        .refresh-menu-button svg {
            width: 16px;
            height: 16px;
            flex: 0 0 16px;
        }
        .refresh-dropdown {
            position: absolute;
            top: calc(100% + 10px);
            right: 0;
            width: 179px;
            border: 1px solid rgba(102, 123, 161, 0.3);
            border-radius: 18px;
            background: #2f3d58;
            color: #f0f5ff;
            box-shadow: 0 24px 48px rgba(0, 0, 0, 0.35);
            opacity: 0;
            transform: translateY(8px);
            pointer-events: none;
            transition: opacity .18s ease, transform .18s ease;
            z-index: 20;
            overflow: hidden;
        }
        .refresh-control.is-open .refresh-dropdown {
            opacity: 1;
            transform: translateY(0);
            pointer-events: auto;
        }
        .refresh-dropdown::before {
            content: "";
            position: absolute;
            top: -8px;
            right: 28px;
            width: 16px;
            height: 16px;
            background: #2f3d58;
            border-left: 1px solid rgba(102, 123, 161, 0.3);
            border-top: 1px solid rgba(102, 123, 161, 0.3);
            transform: rotate(45deg);
        }
        .refresh-toggle-row {
            position: relative;
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 12px 14px;
            border-bottom: 1px solid rgba(102, 123, 161, 0.24);
            font-size: 14px;
            font-weight: 700;
        }
        .refresh-toggle-row .switch {
            width: 36px;
            height: 20px;
            flex: 0 0 36px;
        }
        .refresh-toggle-row .slider {
            border-width: 0;
        }
        .refresh-toggle-row .slider::before {
            width: 14px;
            height: 14px;
            top: 2px;
            left: 3px;
        }
        .refresh-toggle-row .switch input:checked + .slider::before {
            transform: translateX(16px);
        }
        .refresh-options {
            padding: 10px 12px 12px;
        }
        .refresh-options-label {
            margin: 0 0 7px;
            color: #c3cee2;
            font-size: 12px;
            font-weight: 600;
        }
        .refresh-option {
            width: 100%;
            border: 0;
            border-radius: 12px;
            padding: 8px 11px;
            background: transparent;
            color: #eaf1ff;
            text-align: left;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
        }
        .refresh-option:hover,
        .refresh-option.is-active {
            background: rgba(8, 160, 138, 0.18);
        }
        .command-card {
            margin-top: 20px;
            border: 1px solid var(--line);
            border-radius: 22px;
            background: rgba(17, 27, 48, 0.92);
            overflow: hidden;
        }
        .command-head {
            padding: 16px 18px;
            border-bottom: 1px solid var(--line);
            display: flex;
            justify-content: space-between;
            gap: 14px;
            align-items: center;
        }
        .command-head h3 {
            margin: 0;
            font-size: 16px;
            font-weight: 700;
        }
        .command-head p {
            margin: 0;
            color: var(--muted);
            font-size: 11px;
        }
        pre {
            margin: 0;
            padding: 18px;
            min-height: 150px;
            background: #08101d;
            color: #d8e1f5;
            overflow: auto;
            white-space: pre-wrap;
            word-break: break-word;
            line-height: 1.45;
            font-size: 12px;
        }
        @media (max-width: 1160px) {
            .overview-strip {
                grid-template-columns: repeat(2, minmax(0, 1fr));
            }
        }
        @media (max-width: 760px) {
            .page {
                width: min(100%, calc(100% - 16px));
                padding-top: 16px;
            }
            .button-row {
                justify-content: space-between;
            }
            .refresh-group {
                flex: 0 0 auto;
            }
            .refresh-button,
            .refresh-menu-button {
                width: 34px;
                height: 34px;
                flex: 0 0 34px;
            }
            .refresh-button svg,
            .refresh-menu-button svg {
                width: 18px;
                height: 18px;
                flex: 0 0 18px;
            }
            .topbar,
            .panel-header,
            .command-head {
                flex-direction: column;
                align-items: stretch;
            }
            .overview-strip {
                grid-template-columns: 1fr;
            }
            .health-head {
                flex-direction: column;
                align-items: stretch;
            }
            th, td {
                padding: 14px 12px;
            }
        }
    </style>
</head>
<body>
<main class="page">
    <section class="topbar">
        <div class="brand">
            <div class="brand-mark">
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M20.665 4.717c.298-.12.62.145.55.45l-2.816 12.98a.44.44 0 0 1-.654.28l-4.187-2.53-2.136 2.07a.44.44 0 0 1-.745-.28l.302-3.943 7.178-6.48c.19-.172-.057-.455-.266-.306l-8.867 6.036-3.831-1.23a.439.439 0 0 1-.02-.83l14.492-6.217Z" fill="currentColor"/>
                </svg>
            </div>
            <div>
                <h1>MTProto</h1>
                <p>Управление клиентами и трафиком на сервере.</p>
            </div>
        </div>
        <div class="topbar-actions">
            <button class="button-secondary compact-toggle" type="button" data-compact-toggle>Компактно</button>
            <form method="get" action="/">
                <button class="button-secondary" type="submit" name="logout" value="1">Выйти</button>
            </form>
        </div>
    </section>

    <section class="overview-strip">
        <article class="overview-item">
            <div class="overview-label">Отправлено/получено</div>
            <div class="overview-value">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M4 7h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M13 4l3 3-3 3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                    <path d="M20 17H8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M11 14l-3 3 3 3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <span><?php echo htmlspecialchars(formatBytes($totalOutbound), ENT_QUOTES, 'UTF-8'); ?> / <?php echo htmlspecialchars(formatBytes($totalInbound), ENT_QUOTES, 'UTF-8'); ?></span>
            </div>
        </article>
        <article class="overview-item">
            <div class="overview-label">Всего трафика</div>
            <div class="overview-value">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <circle cx="12" cy="12" r="8" stroke="currentColor" stroke-width="1.8"/>
                    <path d="M12 7v6h5" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <span><?php echo htmlspecialchars(formatBytes($totalTraffic), ENT_QUOTES, 'UTF-8'); ?></span>
            </div>
        </article>
        <article class="overview-item">
            <div class="overview-label">Общее использование за все время</div>
            <div class="overview-value">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M12 4a8 8 0 1 0 8 8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M12 2v4" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M12 12l4 2" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                </svg>
                <span><?php echo htmlspecialchars(formatBytes($totalTraffic), ENT_QUOTES, 'UTF-8'); ?></span>
            </div>
        </article>
        <article class="overview-item">
            <div class="overview-label">Всего подключений</div>
            <div class="overview-value">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M8 7h11" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M8 12h11" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M8 17h11" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <circle cx="4" cy="7" r="1.5" fill="currentColor"/>
                    <circle cx="4" cy="12" r="1.5" fill="currentColor"/>
                    <circle cx="4" cy="17" r="1.5" fill="currentColor"/>
                </svg>
                <span><?php echo $totalConnections; ?></span>
            </div>
        </article>
        <article class="overview-item">
            <div class="overview-label">Клиенты</div>
            <div class="overview-value">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M16 19a4 4 0 0 0-8 0" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <circle cx="12" cy="10" r="3" stroke="currentColor" stroke-width="1.8"/>
                    <path d="M20 19a4 4 0 0 0-3-3.87" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M4 19a4 4 0 0 1 3-3.87" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                </svg>
                <span class="overview-badges">
                    <span class="overview-pill green"><?php echo $totalUsers; ?></span>
                    <span class="overview-hover">
                        <span class="overview-pill blue" tabindex="0"><?php echo $activeUsers; ?></span>
                        <span class="overview-popover" role="tooltip">
                            <span class="overview-popover-title">Онлайн</span>
                            <span class="overview-popover-list">
                                <?php if ($activeUserNames === []): ?>
                                    <span class="overview-popover-empty">Сейчас нет активных пользователей</span>
                                <?php else: ?>
                                    <?php foreach ($activeUserNames as $activeUserName): ?>
                                        <span><?php echo htmlspecialchars($activeUserName, ENT_QUOTES, 'UTF-8'); ?></span>
                                    <?php endforeach; ?>
                                <?php endif; ?>
                            </span>
                        </span>
                    </span>
                </span>
            </div>
        </article>
        <article class="overview-item">
            <div class="overview-label">Следующий порт</div>
            <div class="overview-value">
                <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                    <path d="M12 5v14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <path d="M5 12h14" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                    <circle cx="12" cy="12" r="8" stroke="currentColor" stroke-width="1.8"/>
                </svg>
                <span><?php echo $nextPort; ?></span>
            </div>
        </article>
    </section>

    <section class="panel">
        <div class="panel-header">
            <div>
                <h2>Клиенты</h2>
            </div>
            <div class="button-row">
                <button type="button" class="button-secondary" data-open-create>
                    <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                        <path d="M12 5v14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                        <path d="M5 12h14" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>
                    </svg>
                    Создать клиента
                </button>
                <div class="refresh-control" data-refresh-control>
                    <div class="refresh-group">
                        <button class="refresh-button" type="button" data-refresh-now aria-label="Обновить страницу">
                            <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                <path d="M20 12a8 8 0 1 1-2.34-5.66" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
                                <path d="M20 4v5h-5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
                            </svg>
                        </button>
                        <button class="refresh-menu-button" type="button" data-refresh-menu aria-label="Настройки автообновления" aria-expanded="false">
                            <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                <path d="M7 9l5 6 5-6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
                            </svg>
                        </button>
                    </div>
                    <div class="refresh-dropdown" role="menu">
                        <label class="refresh-toggle-row">
                            <span class="switch">
                                <input type="checkbox" data-auto-refresh-toggle>
                                <span class="slider"></span>
                            </span>
                            <span>Автообновление</span>
                        </label>
                        <div class="refresh-options">
                            <p class="refresh-options-label">Интервал</p>
                            <button class="refresh-option" type="button" data-refresh-interval="5">5s</button>
                            <button class="refresh-option" type="button" data-refresh-interval="10">10s</button>
                            <button class="refresh-option" type="button" data-refresh-interval="30">30s</button>
                            <button class="refresh-option" type="button" data-refresh-interval="60">60s</button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <div class="panel-body">
            <?php if ($flash !== null): ?>
                <div class="flash <?php echo htmlspecialchars($flash['type'], ENT_QUOTES, 'UTF-8'); ?>">
                    <?php echo htmlspecialchars($flash['text'], ENT_QUOTES, 'UTF-8'); ?>
                </div>
            <?php endif; ?>

            <div class="table-wrap">
                <table>
                    <thead>
                    <tr>
                        <th>Меню</th>
                        <th>Включить</th>
                        <th>Онлайн</th>
                        <th>Клиент</th>
                        <th>Трафик</th>
                        <th>Отправлено/получено</th>
                    </tr>
                    </thead>
                    <tbody>
                    <?php if ($users === []): ?>
                        <tr>
                            <td colspan="6" style="padding: 28px 16px; text-align: center; color: var(--muted);">Пока нет клиентов. Нажми «Создать клиента».</td>
                        </tr>
                    <?php else: ?>
                        <?php
                        foreach ($users as $user):
                            $isChecked = $user['active'] === 'active' || $user['enabled'] === 'enabled';
                            $monthlyTotal = (int) ($user['month_total_bytes'] ?? 0);
                            $lifetimeTotal = (int) ($user['total_bytes'] ?? 0);
                            $progressSourceTotal = $totalMonthlyTraffic > 0 ? $totalMonthlyTraffic : max($totalTraffic, 0);
                            $progressValue = $totalMonthlyTraffic > 0 ? $monthlyTotal : $lifetimeTotal;
                            $progress = $progressSourceTotal > 0 && $progressValue > 0
                                ? max(8, (int) round(($progressValue / $progressSourceTotal) * 100))
                                : 0;
                        ?>
                            <tr>
                                <td class="menu-cell">
                                    <div class="menu-actions">
                                        <?php if ($user['tg_url'] !== ''): ?>
                                            <button class="icon-button" type="button" title="Скопировать ссылку" data-copy="<?php echo htmlspecialchars($user['tg_url'], ENT_QUOTES, 'UTF-8'); ?>">
                                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                                    <path d="M9 15H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h8a2 2 0 0 1 2 2v4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/>
                                                    <rect x="9" y="9" width="12" height="12" rx="2" stroke="currentColor" stroke-width="1.9"/>
                                                </svg>
                                            </button>
                                        <?php endif; ?>
                                        <form method="post">
                                            <input type="hidden" name="action" value="edit_load">
                                            <input type="hidden" name="user_name" value="<?php echo htmlspecialchars($user['user'], ENT_QUOTES, 'UTF-8'); ?>">
                                            <button class="icon-button" type="submit" title="Редактировать">
                                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                                    <path d="M12 20h9" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
                                                    <path d="M16.5 3.5a2.12 2.12 0 1 1 3 3L7 19l-4 1 1-4 12.5-12.5Z" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/>
                                                </svg>
                                            </button>
                                        </form>
                                        <form method="post">
                                            <input type="hidden" name="action" value="info">
                                            <input type="hidden" name="user_name" value="<?php echo htmlspecialchars($user['user'], ENT_QUOTES, 'UTF-8'); ?>">
                                            <button class="icon-button" type="submit" title="Информация">
                                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                                    <circle cx="12" cy="12" r="9" stroke="currentColor" stroke-width="1.9"/>
                                                    <path d="M12 10v6" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
                                                    <circle cx="12" cy="7" r="1" fill="currentColor"/>
                                                </svg>
                                            </button>
                                        </form>
                                        <form method="post" onsubmit="return confirm('Удалить клиента <?php echo htmlspecialchars($user['user'], ENT_QUOTES, 'UTF-8'); ?>?');">
                                            <input type="hidden" name="action" value="remove">
                                            <input type="hidden" name="user_name" value="<?php echo htmlspecialchars($user['user'], ENT_QUOTES, 'UTF-8'); ?>">
                                            <button class="icon-button danger" type="submit" title="Удалить">
                                                <svg width="22" height="22" viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                                    <path d="M3 6h18" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>
                                                    <path d="M8 6V4a1 1 0 0 1 1-1h6a1 1 0 0 1 1 1v2" stroke="currentColor" stroke-width="1.9"/>
                                                    <path d="M19 6l-1 14a1 1 0 0 1-1 1H7a1 1 0 0 1-1-1L5 6" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/>
                                                </svg>
                                            </button>
                                        </form>
                                    </div>
                                </td>
                                <td class="switch-cell">
                                    <form class="switch-form" method="post">
                                        <input type="hidden" name="action" value="toggle">
                                        <input type="hidden" name="user_name" value="<?php echo htmlspecialchars($user['user'], ENT_QUOTES, 'UTF-8'); ?>">
                                        <label class="switch" title="<?php echo $isChecked ? 'Выключить сервис' : 'Включить сервис'; ?>">
                                            <input type="checkbox" <?php echo $isChecked ? 'checked' : ''; ?> onchange="this.form.submit()">
                                            <span class="slider"></span>
                                        </label>
                                    </form>
                                </td>
                                <td class="online-cell">
                                    <span class="badge <?php echo ($user['online_connections'] ?? 0) > 0 ? 'online' : 'offline'; ?>">
                                        <?php echo ($user['online_connections'] ?? 0) > 0 ? 'Онлайн' : 'Офлайн'; ?>
                                    </span>
                                </td>
                                <td class="client-cell">
                                    <div class="client-name">
                                        <span class="client-dot"></span>
                                        <span><?php echo htmlspecialchars($user['user'], ENT_QUOTES, 'UTF-8'); ?></span>
                                        <span class="chip">Порт <?php echo htmlspecialchars($user['port'], ENT_QUOTES, 'UTF-8'); ?></span>
                                    </div>
                                </td>
                                <td class="traffic-cell">
                                    <div class="traffic-row">
                                        <div class="traffic-total"><?php echo htmlspecialchars(formatBytes($user['total_bytes']), ENT_QUOTES, 'UTF-8'); ?></div>
                                        <div class="traffic-bar">
                                            <span style="width: <?php echo $progress; ?>%;"></span>
                                        </div>
                                    </div>
                                </td>
                                <td class="direction-cell">
                                    <div class="direction-row">
                                        <svg viewBox="0 0 24 24" fill="none" aria-hidden="true">
                                            <path d="M4 7h12" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                                            <path d="M13 4l3 3-3 3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                                            <path d="M20 17H8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
                                            <path d="M11 14l-3 3 3 3" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/>
                                        </svg>
                                        <span><?php echo htmlspecialchars(formatBytes($user['out_bytes']), ENT_QUOTES, 'UTF-8'); ?> / <?php echo htmlspecialchars(formatBytes($user['in_bytes']), ENT_QUOTES, 'UTF-8'); ?></span>
                                    </div>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                    </tbody>
                </table>
            </div>

        </div>
    </section>

    <section class="command-card">
        <div class="command-head">
            <div>
                <h3>Вывод команды</h3>
                <p>Последний результат действия: информация, редактирование, включение или удаление.</p>
            </div>
        </div>
        <pre><?php echo htmlspecialchars($details['output'] ?? 'Команда еще не выполнялась.', ENT_QUOTES, 'UTF-8'); ?></pre>
    </section>

    <section class="health-panel">
        <div class="health-head">
            <div>
                <h2>Проверка здоровья</h2>
                <p>Диагностика MTProto, мониторинга, iptables и веб-панели.</p>
            </div>
            <span class="health-summary <?php echo htmlspecialchars($healthSummaryStatus, ENT_QUOTES, 'UTF-8'); ?>">
                <?php echo htmlspecialchars($healthSummaryText, ENT_QUOTES, 'UTF-8'); ?>
                · OK: <?php echo $healthOk; ?>
                · Внимание: <?php echo $healthWarnings; ?>
                · Ошибки: <?php echo $healthErrors; ?>
            </span>
        </div>
        <div class="health-table-wrap">
            <table class="health-table">
                <thead>
                <tr>
                    <th>Проверка</th>
                    <th>Статус</th>
                    <th>Детали</th>
                </tr>
                </thead>
                <tbody>
                <?php foreach ($healthChecks as $check): ?>
                    <?php
                        $statusLabel = match ($check['status']) {
                            'ok' => 'OK',
                            'warning' => 'Внимание',
                            default => 'Ошибка',
                        };
                    ?>
                    <tr>
                        <td class="health-name"><?php echo htmlspecialchars($check['label'], ENT_QUOTES, 'UTF-8'); ?></td>
                        <td>
                            <span class="health-status <?php echo htmlspecialchars($check['status'], ENT_QUOTES, 'UTF-8'); ?>">
                                <?php echo htmlspecialchars($statusLabel, ENT_QUOTES, 'UTF-8'); ?>
                            </span>
                        </td>
                        <td class="health-details"><?php echo htmlspecialchars($check['details'], ENT_QUOTES, 'UTF-8'); ?></td>
                    </tr>
                <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </section>
</main>
<div class="modal-backdrop<?php echo ($modalMode !== null) ? ' is-open' : ''; ?>" id="editor-modal">
    <div class="modal-card" role="dialog" aria-modal="true" aria-labelledby="editor-title">
        <div class="modal-head">
            <div>
                <h3 id="editor-title"><?php echo $isEditModal ? 'Редактировать клиента' : 'Создать клиента'; ?></h3>
                <p><?php echo $isEditModal ? 'Измени имя, порт или пересоздай secret через новый hostname.' : 'Создание нового MTProto-клиента на отдельном порту.'; ?></p>
            </div>
            <button class="modal-close" type="button" data-close-modal aria-label="Закрыть">×</button>
        </div>
        <div class="modal-body">
            <form method="post">
                <input type="hidden" name="action" value="<?php echo $isEditModal ? 'edit_save' : 'add'; ?>">
                <?php if ($isEditModal): ?>
                    <input type="hidden" name="original_user" value="<?php echo htmlspecialchars($editValues['original_user'], ENT_QUOTES, 'UTF-8'); ?>">
                <?php endif; ?>
                <div class="field">
                    <label>Имя клиента</label>
                    <input name="user_name" value="<?php echo htmlspecialchars($isEditModal ? $editValues['user_name'] : '', ENT_QUOTES, 'UTF-8'); ?>" required>
                </div>
                <div class="field">
                    <label>Порт</label>
                    <input name="port" value="<?php echo htmlspecialchars($isEditModal ? $editValues['port'] : (string) $nextPort, ENT_QUOTES, 'UTF-8'); ?>" required>
                </div>
                <div class="field">
                    <label>Hostname FQDN</label>
                    <input name="hostname_fqdn" value="<?php echo htmlspecialchars($editValues['hostname_fqdn'], ENT_QUOTES, 'UTF-8'); ?>" placeholder="необязательно">
                </div>
                <div class="button-row">
                    <button class="button-primary" type="submit"><?php echo $isEditModal ? 'Сохранить' : 'Создать'; ?></button>
                    <button class="button-secondary" type="button" data-close-modal>Отмена</button>
                </div>
            </form>
        </div>
    </div>
</div>
<script>
    function bindCopyButtons(root = document) {
        root.querySelectorAll('[data-copy]').forEach(function(button) {
            if (button.dataset.copyBound === '1') {
                return;
            }
            button.dataset.copyBound = '1';
            button.addEventListener('click', async function() {
                const text = button.getAttribute('data-copy') || '';
                if (!text) return;
                try {
                    await navigator.clipboard.writeText(text);
                    const originalTitle = button.getAttribute('title') || '';
                    button.setAttribute('title', 'Скопировано');
                    setTimeout(function() {
                        button.setAttribute('title', originalTitle);
                    }, 1200);
                } catch (error) {
                    alert('Не удалось скопировать ссылку');
                }
            });
        });
    }

    bindCopyButtons();
    const modal = document.getElementById('editor-modal');
    const openCreateButton = document.querySelector('[data-open-create]');
    const closeButtons = document.querySelectorAll('[data-close-modal]');
    if (openCreateButton && modal) {
        openCreateButton.addEventListener('click', function() {
            modal.classList.add('is-open');
        });
    }
    closeButtons.forEach(function(button) {
        button.addEventListener('click', function() {
            window.location.href = '/';
        });
    });
    if (modal) {
        modal.addEventListener('click', function(event) {
            if (event.target === modal) {
                window.location.href = '/';
            }
        });
    }
    const refreshControl = document.querySelector('[data-refresh-control]');
    const refreshMenuButton = document.querySelector('[data-refresh-menu]');
    const refreshNowButton = document.querySelector('[data-refresh-now]');
    const autoRefreshToggle = document.querySelector('[data-auto-refresh-toggle]');
    const refreshIntervalButtons = document.querySelectorAll('[data-refresh-interval]');
    const compactToggleButton = document.querySelector('[data-compact-toggle]');
    const refreshStorageKey = 'mtproto_auto_refresh';
    const intervalStorageKey = 'mtproto_refresh_interval';
    const compactStorageKey = 'mtproto_compact_mode';
    let refreshTimer = null;

    function getRefreshInterval() {
        const storedInterval = Number(window.localStorage.getItem(intervalStorageKey) || '5');
        return [5, 10, 30, 60].includes(storedInterval) ? storedInterval : 5;
    }

    function updateRefreshOptions() {
        const activeInterval = String(getRefreshInterval());
        refreshIntervalButtons.forEach(function(button) {
            button.classList.toggle('is-active', button.getAttribute('data-refresh-interval') === activeInterval);
        });
    }

    function stopAutoRefresh() {
        if (refreshTimer !== null) {
            window.clearInterval(refreshTimer);
            refreshTimer = null;
        }
    }

    async function refreshPageData() {
        if (modal && modal.classList.contains('is-open')) {
            return;
        }
        try {
            const response = await window.fetch(window.location.href, {
                cache: 'no-store',
                credentials: 'same-origin',
                headers: {
                    'X-Requested-With': 'fetch'
                }
            });
            if (!response.ok || response.redirected) {
                throw new Error('Refresh failed');
            }
            const html = await response.text();
            const nextDocument = new DOMParser().parseFromString(html, 'text/html');
            const currentOverview = document.querySelector('.overview-strip');
            const nextOverview = nextDocument.querySelector('.overview-strip');
            const currentTableBody = document.querySelector('.table-wrap tbody');
            const nextTableBody = nextDocument.querySelector('.table-wrap tbody');
            const currentHealthTableBody = document.querySelector('.health-table tbody');
            const nextHealthTableBody = nextDocument.querySelector('.health-table tbody');
            const currentHealthSummary = document.querySelector('.health-summary');
            const nextHealthSummary = nextDocument.querySelector('.health-summary');

            if (currentOverview && nextOverview) {
                currentOverview.innerHTML = nextOverview.innerHTML;
            }
            if (currentTableBody && nextTableBody) {
                currentTableBody.innerHTML = nextTableBody.innerHTML;
                bindCopyButtons(currentTableBody);
            }
            if (currentHealthTableBody && nextHealthTableBody) {
                currentHealthTableBody.innerHTML = nextHealthTableBody.innerHTML;
            }
            if (currentHealthSummary && nextHealthSummary) {
                currentHealthSummary.className = nextHealthSummary.className;
                currentHealthSummary.innerHTML = nextHealthSummary.innerHTML;
            }
        } catch (error) {
            console.warn('Не удалось тихо обновить страницу', error);
        }
    }

    function startAutoRefresh() {
        stopAutoRefresh();
        refreshTimer = window.setInterval(function() {
            refreshPageData();
        }, getRefreshInterval() * 1000);
    }

    function applyAutoRefreshState() {
        const enabled = window.localStorage.getItem(refreshStorageKey) === '1';
        if (autoRefreshToggle) {
            autoRefreshToggle.checked = enabled;
        }
        updateRefreshOptions();
        if (enabled) {
            startAutoRefresh();
        } else {
            stopAutoRefresh();
        }
    }

    function applyCompactModeState() {
        const enabled = window.localStorage.getItem(compactStorageKey) === '1';
        document.body.classList.toggle('compact', enabled);
        if (compactToggleButton) {
            compactToggleButton.classList.toggle('is-active', enabled);
            compactToggleButton.textContent = enabled ? 'Обычно' : 'Компактно';
        }
    }

    if (refreshNowButton) {
        refreshNowButton.addEventListener('click', function() {
            refreshPageData();
        });
    }
    if (refreshControl && refreshMenuButton) {
        refreshMenuButton.addEventListener('click', function(event) {
            event.stopPropagation();
            const isOpen = refreshControl.classList.toggle('is-open');
            refreshMenuButton.setAttribute('aria-expanded', isOpen ? 'true' : 'false');
        });
        document.addEventListener('click', function(event) {
            if (!refreshControl.contains(event.target)) {
                refreshControl.classList.remove('is-open');
                refreshMenuButton.setAttribute('aria-expanded', 'false');
            }
        });
    }
    if (autoRefreshToggle) {
        autoRefreshToggle.addEventListener('change', function() {
            window.localStorage.setItem(refreshStorageKey, autoRefreshToggle.checked ? '1' : '0');
            applyAutoRefreshState();
        });
    }
    refreshIntervalButtons.forEach(function(button) {
        button.addEventListener('click', function() {
            window.localStorage.setItem(intervalStorageKey, button.getAttribute('data-refresh-interval') || '5');
            updateRefreshOptions();
            if (autoRefreshToggle && autoRefreshToggle.checked) {
                startAutoRefresh();
            }
        });
    });
    if (compactToggleButton) {
        compactToggleButton.addEventListener('click', function() {
            const enabled = window.localStorage.getItem(compactStorageKey) === '1';
            window.localStorage.setItem(compactStorageKey, enabled ? '0' : '1');
            applyCompactModeState();
        });
    }
    applyCompactModeState();
    applyAutoRefreshState();
</script>
</body>
</html>
