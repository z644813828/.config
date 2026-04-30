<!DOCTYPE html>
<html lang="en" class="no-js">
<style>
   .scale {
    transition: 0.7s; /* Время эффекта */
   }
   .scale:hover {
    transform: scale(1.2); /* Увеличиваем масштаб */
   }
   .scale2 {
    transition: 0.5s; /* Время эффекта */
   }
   .scale2:hover {
   transform: rotate(10deg);
   }
   .feature-inner {
    position: relative;
   }
   .panel-toggle {
    border: 0;
    background: transparent;
    padding: 0;
    cursor: pointer;
   }
   .panel-toggle:focus-visible {
    outline: 2px solid #fff;
    outline-offset: 8px;
    border-radius: 20px;
   }
   .panel-menu {
    display: block;
    width: 100%;
    margin-top: 18px;
    text-align: left;
    padding: 0 14px;
    background: transparent;
    box-shadow: none;
    max-height: 0;
    opacity: 0;
    overflow: hidden;
    transform: translateY(-8px);
    pointer-events: none;
    transition: max-height 0.2s ease, opacity 0.2s ease, transform 0.2s ease;
   }
   .panel-menu.is-open {
    max-height: 180px;
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
   }
   .feature.has-open-panel {
    margin-bottom: 24px;
   }
   .panel-menu a {
    display: block;
    padding: 0;
    color: #8A94A7;
    text-decoration: none;
    font-size: 18px;
    line-height: 28px;
    font-weight: 400;
    letter-spacing: -0.1px;
    transition: color 0.2s ease;
   }
   .panel-entry {
    display: flex;
    align-items: center;
    justify-content: flex-start;
    gap: 10px;
    width: 100%;
   }
   .panel-main-link {
    display: inline-flex !important;
    align-items: center;
    justify-content: flex-start;
    flex: 1 1 auto;
    min-width: 0;
    text-align: left;
   }
   .panel-tg-link {
    display: inline-flex !important;
    align-items: center;
    justify-content: center;
    flex: 0 0 auto;
    margin-left: auto;
    width: 20px;
    height: 20px;
    color: #8A94A7;
   }
   .panel-tg-link svg {
    width: 18px;
    height: 18px;
    fill: currentColor;
   }
   .panel-tg-link:hover {
    color: #54A9EB !important;
   }
   .panel-flag {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 18px;
    margin-right: 10px;
    font-size: 18px;
    line-height: 1;
    vertical-align: -3px;
   }
   .panel-menu a:hover {
    color: #fff;
   }
   .feature-title-with-status {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: 9px;
   }
   .status-dot {
    display: inline-block;
    flex: 0 0 auto;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    background: #8A94A7;
    box-shadow: 0 0 0 4px rgba(138, 148, 167, 0.1);
    vertical-align: middle;
    cursor: pointer;
   }
   .status-dot-ok {
    background: #16d19a;
    box-shadow: 0 0 0 4px rgba(22, 209, 154, 0.12);
   }
   .status-dot-warn {
    background: #f2c94c;
    box-shadow: 0 0 0 4px rgba(242, 201, 76, 0.14);
   }
   .status-dot-down {
    background: #ff6b6b;
    box-shadow: 0 0 0 4px rgba(255, 107, 107, 0.14);
   }
   .status-dot-unknown {
    background: #8A94A7;
   }
   .status-dot-pulse {
    margin-left: 10px;
    animation: statusPulse 1.4s ease-in-out infinite;
   }
   .hero-status-dot {
    margin-right: 10px;
   }
   @keyframes statusPulse {
    0%, 100% {
        transform: scale(1);
        opacity: 0.75;
    }
    50% {
        transform: scale(1.45);
        opacity: 1;
    }
   }
   .status-popover {
    position: fixed;
    z-index: 1000;
    max-width: min(320px, calc(100vw - 32px));
    padding: 12px 14px;
    border: 1px solid rgba(138, 148, 167, 0.22);
    border-radius: 12px;
    color: #d8deea;
    background: rgba(36, 40, 48, 0.96);
    box-shadow: 0 16px 42px rgba(0, 0, 0, 0.36);
    font-size: 13px;
    line-height: 19px;
    text-align: left;
    white-space: pre-line;
    opacity: 0;
    transform: translateY(6px);
    pointer-events: none;
    transition: opacity 0.16s ease, transform 0.16s ease;
   }
   .status-popover.is-open {
    opacity: 1;
    transform: translateY(0);
    pointer-events: auto;
   }
   @media (max-width: 640px) {
    .hero-title {
        font-size: 34px;
        line-height: 42px;
        overflow-wrap: normal;
    }
    .panel-menu {
        margin-top: 20px;
        padding-left: 18px;
        padding-right: 18px;
    }
    .feature.has-open-panel {
        margin-bottom: 40px;
    }
   }
   @media (min-width: 641px) {
    .hero-title {
        white-space: nowrap;
    }
   }
</style>

<?php
function loadEnvFile(string $path)
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
        if ($trimmed === '' || substr($trimmed, 0, 1) === '#') {
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

function detectPublicHost(): string
{
    if (function_exists('shell_exec')) {
        $detected = @shell_exec('curl -fsS --max-time 2 ifconfig.me 2>/dev/null');
        $detected = trim((string) $detected);
        if ($detected !== '') {
            return $detected;
        }
    }

    return '127.0.0.1';
}

function loadPanels(): array
{
    $panels = array();
    $panelCount = (int) envValue('OMV_3XUI_PANELS', '0');

    if ($panelCount > 0) {
        for ($i = 1; $i <= $panelCount; $i++) {
            $name = envValue('OMV_3XUI_PANEL_' . $i . '_NAME', '');
            $country = envValue('OMV_3XUI_PANEL_' . $i . '_COUNTRY', '');
            $url = envValue('OMV_3XUI_PANEL_' . $i . '_URL', '');
            $tgUrl = envValue('OMV_3XUI_PANEL_' . $i . '_TG_URL', '');

            if ($name === '' || $url === '') {
                continue;
            }

            $panels[] = array(
                'name' => $name,
                'country' => $country,
                'url' => $url,
                'tg_url' => $tgUrl,
            );
        }
    }

    if (!empty($panels)) {
        return $panels;
    }

    return array(
        array(
            'name' => envValue('OMV_3XUI_PANEL_NAME', 'Panel'),
            'country' => envValue('OMV_3XUI_PANEL_COUNTRY', 'us'),
            'url' => envValue('OMV_3XUI_PANEL_URL', '#'),
            'tg_url' => envValue('OMV_MTPROTO_WEB_URL', '#'),
        )
    );
}

function countryFlagHtml(string $country): string
{
    $country = strtoupper(trim($country));
    if (strlen($country) !== 2 || !ctype_alpha($country)) {
        return '';
    }

    $first = 0x1F1E6 + ord($country[0]) - ord('A');
    $second = 0x1F1E6 + ord($country[1]) - ord('A');

    return '&#x' . strtoupper(dechex($first)) . ';&#x' . strtoupper(dechex($second)) . ';';
}

function normalizedHttpHost(): string
{
    $httpHost = trim((string) ($_SERVER['HTTP_HOST'] ?? ''));
    if ($httpHost === '') {
        return '';
    }

    $normalized = preg_replace('~:\d+$~', '', $httpHost);
    return $normalized === null ? $httpHost : $normalized;
}

function localHostList(string $primaryLocalHost): array
{
    $hosts = array($primaryLocalHost);
    $extraHosts = envValue('OMV_EXTRA_LOCAL_HOSTS', '');

    if ($extraHosts !== '') {
        foreach (explode(',', $extraHosts) as $host) {
            $host = trim($host);
            if ($host !== '') {
                $hosts[] = $host;
            }
        }
    }

    return array_unique($hosts);
}

function loadServiceStatus(string $path): array
{
    if (!is_file($path) || !is_readable($path)) {
        return array();
    }

    $raw = file_get_contents($path);
    if ($raw === false || $raw === '') {
        return array();
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded) || !isset($decoded['services']) || !is_array($decoded['services'])) {
        return array();
    }

    return $decoded['services'];
}

function loadServiceStatusGeneratedAt(string $path): string
{
    if (!is_file($path) || !is_readable($path)) {
        return '';
    }

    $raw = file_get_contents($path);
    if ($raw === false || $raw === '') {
        return '';
    }

    $decoded = json_decode($raw, true);
    if (!is_array($decoded) || !isset($decoded['generated_at'])) {
        return '';
    }

    return (string) $decoded['generated_at'];
}

function serviceStatus(array $statuses, string $key): array
{
    if (!isset($statuses[$key]) || !is_array($statuses[$key])) {
        return array(
            'status' => 'unknown',
            'label' => '?',
            'message' => 'status not collected yet',
            'details' => '',
            'checked_at' => '',
        );
    }

    $item = $statuses[$key];
    $status = isset($item['status']) ? strtolower((string) $item['status']) : 'unknown';
    if (!in_array($status, array('ok', 'warn', 'down', 'unknown'), true)) {
        $status = 'unknown';
    }

    $labels = array(
        'ok' => 'OK',
        'warn' => 'WARN',
        'down' => 'DOWN',
        'unknown' => '?',
    );

    return array(
        'status' => $status,
        'label' => $labels[$status],
        'message' => isset($item['message']) ? (string) $item['message'] : '',
        'details' => isset($item['details']) ? (string) $item['details'] : '',
        'checked_at' => isset($item['checked_at']) ? (string) $item['checked_at'] : '',
    );
}

function overallServiceStatus(array $statuses, string $generatedAt = ''): array
{
    if (empty($statuses)) {
        return array(
            'status' => 'unknown',
            'message' => 'service status file not collected yet',
            'details' => '',
            'checked_at' => $generatedAt,
        );
    }

    $rank = array(
        'ok' => 0,
        'unknown' => 1,
        'warn' => 2,
        'down' => 3,
    );
    $worst = 'ok';
    $counts = array(
        'ok' => 0,
        'unknown' => 0,
        'warn' => 0,
        'down' => 0,
    );

    foreach ($statuses as $item) {
        if (!is_array($item)) {
            continue;
        }

        $status = isset($item['status']) ? strtolower((string) $item['status']) : 'unknown';
        if (!isset($rank[$status])) {
            $status = 'unknown';
        }

        $counts[$status]++;
        if ($rank[$status] > $rank[$worst]) {
            $worst = $status;
        }
    }

    return array(
        'status' => $worst,
        'message' => 'ok: ' . $counts['ok'] . ', warn: ' . $counts['warn'] . ', down: ' . $counts['down'] . ', unknown: ' . $counts['unknown'],
        'details' => 'service-status.json',
        'checked_at' => $generatedAt,
    );
}

function statusPopupText(array $status): string
{
    $lines = array('Status: ' . strtoupper((string) ($status['status'] ?? 'unknown')));

    if (!empty($status['message'])) {
        $lines[] = 'Message: ' . (string) $status['message'];
    }
    if (!empty($status['details'])) {
        $lines[] = 'Details: ' . (string) $status['details'];
    }
    if (!empty($status['checked_at'])) {
        $lines[] = 'Date: ' . (string) $status['checked_at'];
    }

    return implode("\n", $lines);
}

loadEnvFile(__DIR__ . '/.env');

$localIpHost = '192.168.2.254';
$currentHttpHost = normalizedHttpHost();
$localHosts = localHostList($localIpHost);
$isLocal = in_array($currentHttpHost, $localHosts, true);
$localIpHostForLinks = $isLocal && $currentHttpHost !== '' ? $currentHttpHost : $localIpHost;
$localIp = 'https://' . $localIpHostForLinks;
$ddnsName = envValue('OMV_DDNS_URL', 'https://example.invalid');
$publicHost = detectPublicHost();
$publicHttpUrl = preg_match('~^https?://~', $publicHost) ? $publicHost : 'https://' . $publicHost;
$githubConfigUrl = envValue('OMV_GITHUB_CONFIG_URL', 'https://github.com/example/repo');
$asusRouterRemoteUrl = envValue('OMV_ASUS_REMOTE_URL', '#');
$asusRouterLocalHost = $localIpHostForLinks === '10.80.0.10' ? '10.80.0.10' : '192.168.2.1';
$asusRouterLocalUrl = 'https://' . $asusRouterLocalHost . ':8443/Main_Login.asp';
$keeneticRemoteUrl = envValue('OMV_KEENETIC_REMOTE_URL', '#');
$keeneticLocalUrl = 'http://192.168.1.1';
$panels = loadPanels();
$serviceStatusFile = envValue('OMV_SERVICE_STATUS_FILE', __DIR__ . '/service-status.json');
$serviceStatuses = loadServiceStatus($serviceStatusFile);
$serviceStatusGeneratedAt = loadServiceStatusGeneratedAt($serviceStatusFile);
$overallStatus = overallServiceStatus($serviceStatuses, $serviceStatusGeneratedAt);
$overallStatusText = statusPopupText($overallStatus);
?>

<head>
	<meta charset="utf-8">
	<meta http-equiv="X-UA-Compatible" content="IE=edge">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>OpenMediaVault home page</title>
    <link rel="stylesheet" href="https://fonts.googleapis.com/css?family=Tangerine">
	<link rel="stylesheet" href="dist/css/style.css">
	<script src="dist/js/anime.min.js"></script>
	<script src="dist/js/scrollreveal.min.js"></script>
</head>

<body class="is-boxed has-animations">
	<div class="body-wrap">
		<header class="site-header">
			<div class="container">
				<div class="site-header-inner">
					<div class="brand header-brand">
						<h1 class="m-0">
							<a href="#">
								<img class="header-logo-image scale" src="dist/images/logo.svg" alt="Logo">
							</a>
						</h1>
					</div>
				</div>
			</div>
		</header>

		<main>
			<section class="hero">
				<div class="container">
					<div class="hero-inner">
						<div class="hero-copy">
							<h1 class="hero-title mt-0">OpenMediaVault Server</h1>
								<p class="hero-paragraph">
	                                    <span
	                                        class="status-dot status-dot-<?php echo htmlspecialchars($overallStatus['status'], ENT_QUOTES, "UTF-8"); ?> status-dot-pulse hero-status-dot"
	                                        title="<?php echo htmlspecialchars($overallStatusText, ENT_QUOTES, "UTF-8"); ?>"
                                            data-status-popover="<?php echo htmlspecialchars($overallStatusText, ENT_QUOTES, "UTF-8"); ?>"
                                            role="button"
                                            tabindex="0"
	                                    ></span>
                                    Running services redirect page.
                                </p>
							<div class="hero-cta">
                                <a class="button button-primary scale"
                                 href="<?php echo $isLocal ? $ddnsName : $localIp?>">
                                 Switch to <?php echo $isLocal ? "DDNS" : "Local host"?>
                                </a>
                                <a class="button scale" href="<?php echo htmlspecialchars($githubConfigUrl, ENT_QUOTES, "UTF-8"); ?>">
                                 Configuration
                                </a>
							</div>
						</div>
						<div class="hero-figure anime-element">
							<svg class="placeholder" width="528" height="396" viewBox="0 0 528 396">
								<rect width="528" height="396" style="fill:transparent;" />
							</svg>
							<div class="hero-figure-box hero-figure-box-01" data-rotation="45deg"></div>
							<div class="hero-figure-box hero-figure-box-02" data-rotation="-45deg"></div>
							<div class="hero-figure-box hero-figure-box-03" data-rotation="0deg"></div>
							<div class="hero-figure-box hero-figure-box-04" data-rotation="-135deg"></div>
							<div class="hero-figure-box hero-figure-box-05"></div>
							<div class="hero-figure-box hero-figure-box-06"></div>
							<div class="hero-figure-box hero-figure-box-07"></div>
							<div class="hero-figure-box hero-figure-box-08" data-rotation="-22deg"></div>
							<div class="hero-figure-box hero-figure-box-09" data-rotation="-52deg"></div>
							<div class="hero-figure-box hero-figure-box-10" data-rotation="-50deg"></div>
						</div>
					</div>
				</div>
			</section>
			
			<?php
                $data = array(
                    [
                        "openmediavault.php",
                        "openmediavault.php",
                        "OpenMediaVault.png",
                        "OpenMediaVault.",
                        "Openmediavault is the next generation network attached storage (NAS) solution based on Debian Linux.
						It contains services like SSH, (S)FTP, SMB/CIFS, DAAP media server, RSync, BitTorrent client and many more.",
                        "openmediavault"
                    ],
                    [
                        "#",
                        "#",
                        "3x-ui.png",
                        "3x-ui",
                        "Access server panels from a dropdown opened directly on the tile. Quickly switch between locations and open the needed 3x-ui instance for management, monitoring, and configuration.",
                        "3x-ui"
                    ],
                    [
                        "$ddnsName:8880",
                        "$localIp:8880",
                        "FileBrowser.png",
                        "FileBrowser",
                        "Filebrowser provides a file managing interface within a specified directory and it can be used to upload, delete, preview, rename and edit your files.",
                        "filebrowser"
                    ],
                    [
                        "$ddnsName:18790",
                        "$localIp:18790",
                        "openclaw.png",
                        "OpenClaw",
                        "Jarvis. An open-source, autonomous AI agent that functions as a personal digital assistant.",
                        "openclaw"
                    ],
                    [
                        "$ddnsName:199",
                        "$localIp:199",
                        "NetData.png",
                        "NetData",
                        "Netdata's distributed, real-time monitoring Agent collects thousands of metrics from systems, hardware, containers, and applications with zero configuration.",
                        "netdata"
                    ],
                    [
                        "$ddnsName:4000",
                        "$localIp:2812",
                        "Monit.png",
                        "Monit",
                        "With all features needed for system monitoring and error recovery. It's like having a watchdog with a toolbox on your server",
                        "monit"
                    ],
                    [
                        $asusRouterRemoteUrl,
                        $asusRouterLocalUrl,
                        "AsusRouter.png",
                        "Asus router",
                        "Remote GUI allows you to access your router's online settings, also known as the graphical user interface (GUI), through a WAN connection.",
                        "asus-router"
                    ],
                    [
                        $keeneticRemoteUrl,
                        $keeneticLocalUrl,
                        "Keenetic.png",
                        "Keenetic router",
                        "Remote GUI allows you to access your router's online settings, also known as the graphical user interface (GUI), through a WAN connection.",
                        "keenetic-router"
                    ],
                    [
                        "$ddnsName:9091",
                        "$localIp:9091",
                        "Transmission.png",
                        "Transmission",
                        "Transmission is an open source, volunteer-based project. Unlike some BitTorrent clients, Transmission doesn't play games with its users to make money",
                        "transmission"
                    ],
                    [
                        "ts3server://" . $publicHost . "/?port=9987",
                        "ts3server://" . $publicHost . "/?port=9987",
                        "TeamSpeak.png",
                        "TeamSpeak",
                        "Use crystal clear sound to communicate with your team mates cross-platform with military-grade security, lag-free performance & unparalleled reliability and uptime.",
                        "teamspeak"
                    ],
                    [
                        "apcupsd.php",
                        "apcupsd.php",
                        "ApcUpsD.png",
                        "APC UPS daemon.",
                        "It allows the computer to interact with APC UPSes.",
                        "apcupsd"
                    ],
                    // [
                    //     "$ddnsName:4041/status",
                    //     "$localIp:4041/status",
                    //     "Ngrok.png",
                    //     "Ngrok",
                    //     "Ngrok provides a real-time web UI where you can introspect all HTTP traffic running over your tunnels."
                    // ],
                    [
                        "arduino/index.php",
                        "arduino/index.php",
                        "AsusRog.png",
                        "StreamDeck.",
                        ".",
                        "streamdeck"
                    ]
                );

                define("IDX_PATH", 0);
                define("IDX_LOCAL_PATH", 1);
                define("IDX_IMG", 2);
                define("IDX_NAME", 3);
                define("IDX_DESCRIPTION", 4);
                define("IDX_STATUS_KEY", 5);
             ?>


			<section class="features section">
				<div class="container">
					<div class="features-inner section-inner has-bottom-divider">
						<div class="features-wrap">
								 <?php foreach ($data as $elem): ?>
	                                    <?php $currentStatus = serviceStatus($serviceStatuses, $elem[IDX_STATUS_KEY]); ?>
                                        <?php $currentStatusText = statusPopupText($currentStatus); ?>
									<div class="feature text-center is-revealing scale">
									<div class="feature-inner">
										<div class="feature-icon">
                                            <?php if ($elem[IDX_NAME] === "3x-ui"): ?>
                                                <button class="panel-toggle" type="button" data-panel-toggle="main-3x-ui" aria-expanded="false">
                                                    <img class="scale2 feature-tile-icon" src="dist/images/<?php echo $elem[IDX_IMG]?>" alt="3x-ui">
                                                </button>
                                            <?php else: ?>
                                                <a href="<?php echo $isLocal ? $elem[IDX_LOCAL_PATH] : $elem[IDX_PATH]?>">
                                                    <img class="scale2 feature-tile-icon" src="dist/images/<?php echo $elem[IDX_IMG]?>" alt="Feature 01">
                                                </a>
                                            <?php endif; ?>
										</div>
											<h4 class="feature-title feature-title-with-status mt-24">
                                                <?php echo $elem[IDX_NAME]?>
	                                                <span
	                                                    class="status-dot status-dot-<?php echo htmlspecialchars($currentStatus['status'], ENT_QUOTES, "UTF-8"); ?> status-dot-pulse"
	                                                    title="<?php echo htmlspecialchars($currentStatusText, ENT_QUOTES, "UTF-8"); ?>"
                                                        data-status-popover="<?php echo htmlspecialchars($currentStatusText, ENT_QUOTES, "UTF-8"); ?>"
                                                        role="button"
                                                        tabindex="0"
	                                                ></span>
                                            </h4>
										<p class="text-sm mb-0"><?php echo $elem[IDX_DESCRIPTION]?></p>
                                        <?php if ($elem[IDX_NAME] === "3x-ui"): ?>
                                            <div class="panel-menu" id="main-3x-ui">
                                                <?php foreach ($panels as $panel): ?>
                                                    <div class="panel-entry">
	                                                        <a class="panel-main-link" href="<?php echo htmlspecialchars($panel["url"], ENT_QUOTES, "UTF-8"); ?>" target="_blank" rel="noopener noreferrer">
	                                                            <?php if (!empty($panel["country"])): ?>
	                                                                <span class="panel-flag" aria-hidden="true"><?php echo countryFlagHtml($panel["country"]); ?></span>
	                                                            <?php endif; ?>
                                                            <?php echo htmlspecialchars($panel["name"], ENT_QUOTES, "UTF-8"); ?>
                                                        </a>
                                                        <?php if (!empty($panel["tg_url"])): ?>
                                                            <a class="panel-tg-link" href="<?php echo htmlspecialchars($panel["tg_url"], ENT_QUOTES, "UTF-8"); ?>" target="_blank" rel="noopener noreferrer" title="Open Telegram proxy" aria-label="Open Telegram proxy">
                                                                <svg viewBox="0 0 24 24" aria-hidden="true">
                                                                    <path d="M9.78 18.65c-.39 0-.32-.15-.46-.53l-1.15-3.78 9.41-5.58c.44-.25.75-.12.42.17l-7.63 6.89-.28 3.76c.41 0 .59-.19.82-.41l1.97-1.92 4.1 3.03c.76.42 1.31.2 1.5-.71l2.72-12.82c.28-1.11-.42-1.62-1.14-1.3L3.04 11.12c-1.08.43-1.06 1.03-.19 1.3l4.36 1.36 10.08-6.36c.48-.29.92-.13.56.19"/>
                                                                </svg>
                                                            </a>
                                                        <?php endif; ?>
                                                    </div>
                                                <?php endforeach; ?>
                                            </div>
                                        <?php endif; ?>
									</div>
								</div>
							 <?php endforeach; ?>
						</div>
					</div>
				</div>
			</section>
		</main>

		<footer class="site-footer">
			<div class="container">
				<div class="site-footer-inner">
					<div class="brand footer-brand">
                        <a href="<?php echo htmlspecialchars($publicHttpUrl, ENT_QUOTES, "UTF-8"); ?>">
							<img class="header-logo-image scale" src="dist/images/logo.svg" alt="Logo">
						</a>
					</div>
					<ul class="footer-links list-reset">
						<li>
							<a href="#">Contact</a>
						</li>
						<li>
							<a href="#">About</a>
						</li>
						<li>
							<a href="#">FAQ's</a>
						</li>
						<li>
							<a href="#">Support</a>
						</li>
					</ul>
					<ul class="footer-social-links list-reset">
						<li>
							<a href="#">
								<span class="screen-reader-text">Facebook</span>
								<svg width="16" height="16" xmlns="http://www.w3.org/2000/svg">
									<path d="M6.023 16L6 9H3V6h3V4c0-2.7 1.672-4 4.08-4 1.153 0 2.144.086 2.433.124v2.821h-1.67c-1.31 0-1.563.623-1.563 1.536V6H13l-1 3H9.28v7H6.023z" fill="#0270D7" />
								</svg>
							</a>
						</li>
						<li>
							<a href="#">
								<span class="screen-reader-text">Twitter</span>
								<svg width="16" height="16" xmlns="http://www.w3.org/2000/svg">
									<path
									 d="M16 3c-.6.3-1.2.4-1.9.5.7-.4 1.2-1 1.4-1.8-.6.4-1.3.6-2.1.8-.6-.6-1.5-1-2.4-1-1.7 0-3.2 1.5-3.2 3.3 0 .3 0 .5.1.7-2.7-.1-5.2-1.4-6.8-3.4-.3.5-.4 1-.4 1.7 0 1.1.6 2.1 1.5 2.7-.5 0-1-.2-1.5-.4C.7 7.7 1.8 9 3.3 9.3c-.3.1-.6.1-.9.1-.2 0-.4 0-.6-.1.4 1.3 1.6 2.3 3.1 2.3-1.1.9-2.5 1.4-4.1 1.4H0c1.5.9 3.2 1.5 5 1.5 6 0 9.3-5 9.3-9.3v-.4C15 4.3 15.6 3.7 16 3z"
									 fill="#0270D7" />
								</svg>
							</a>
						</li>
						<li>
							<a href="#">
								<span class="screen-reader-text">Google</span>
								<svg width="16" height="16" xmlns="http://www.w3.org/2000/svg">
									<path d="M7.9 7v2.4H12c-.2 1-1.2 3-4 3-2.4 0-4.3-2-4.3-4.4 0-2.4 2-4.4 4.3-4.4 1.4 0 2.3.6 2.8 1.1l1.9-1.8C11.5 1.7 9.9 1 8 1 4.1 1 1 4.1 1 8s3.1 7 7 7c4 0 6.7-2.8 6.7-6.8 0-.5 0-.8-.1-1.2H7.9z" fill="#0270D7" />
								</svg>
							</a>
						</li>
					</ul>
					<div class="footer-copyright">&copy; <?php echo date("Y"); ?> Dmitriy_K, all rights reserved</div>
				</div>
			</div>
		</footer>
	</div>

	<script src="dist/js/main.min.js"></script>
    <script>
	        (function() {
	            var toggles = document.querySelectorAll("[data-panel-toggle]");
	            toggles.forEach(function(toggle) {
                toggle.addEventListener("click", function() {
                    var menuId = toggle.getAttribute("data-panel-toggle");
                    var menu = document.getElementById(menuId);
                    if (!menu) {
                        return;
                    }
                    var isOpen = menu.classList.toggle("is-open");
                    var feature = toggle.closest(".feature");
                    if (feature) {
                        feature.classList.toggle("has-open-panel", isOpen);
                    }
                    toggle.setAttribute("aria-expanded", isOpen ? "true" : "false");
	                });
	            });
	        })();
        (function() {
            var popover = document.createElement("div");
            popover.className = "status-popover";
            popover.setAttribute("role", "tooltip");
            document.body.appendChild(popover);

            function closePopover() {
                popover.classList.remove("is-open");
                popover.textContent = "";
            }

            function openPopover(dot) {
                var text = dot.getAttribute("data-status-popover");
                if (!text) {
                    return;
                }

                popover.textContent = text;
                popover.classList.add("is-open");

                var rect = dot.getBoundingClientRect();
                var popoverRect = popover.getBoundingClientRect();
                var left = rect.left + rect.width / 2 - popoverRect.width / 2;
                var top = rect.bottom + 12;
                var padding = 16;

                left = Math.max(padding, Math.min(left, window.innerWidth - popoverRect.width - padding));
                if (top + popoverRect.height + padding > window.innerHeight) {
                    top = Math.max(padding, rect.top - popoverRect.height - 12);
                }

                popover.style.left = left + "px";
                popover.style.top = top + "px";
            }

            document.querySelectorAll("[data-status-popover]").forEach(function(dot) {
                dot.addEventListener("click", function(event) {
                    event.stopPropagation();
                    if (popover.classList.contains("is-open") && popover.textContent === dot.getAttribute("data-status-popover")) {
                        closePopover();
                        return;
                    }
                    openPopover(dot);
                });

                dot.addEventListener("keydown", function(event) {
                    if (event.key === "Enter" || event.key === " ") {
                        event.preventDefault();
                        openPopover(dot);
                    }
                });
            });

            document.addEventListener("click", closePopover);
            document.addEventListener("keydown", function(event) {
                if (event.key === "Escape") {
                    closePopover();
                }
            });
            window.addEventListener("resize", closePopover);
            window.addEventListener("scroll", closePopover, true);
        })();
	    </script>
</body>

</html>
