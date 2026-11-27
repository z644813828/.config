<?php
// Extract only pure functions: never execute the panel's session/auth/system calls.
$source = file_get_contents(__DIR__ . '/server-mtproto-admin.php');
foreach (['parsePortConnectionCounts', 'getGroupSummary'] as $name) {
    if (!preg_match('/function ' . $name . '\\([^\n]*\n\\{.*?^\\}/ms', $source, $match)) {
        throw new RuntimeException("Function missing: " . $name);
    }
    eval($match[0]);
}
$counts = parsePortConnectionCounts(
    "128 0 192.0.2.1:8446 198.51.100.4:50001\n" .
    "0 0 192.0.2.1:8447 198.51.100.5:50002 users:((\"other\",pid=102,fd=7))\n" .
    "0 0 192.0.2.1:8443 198.51.100.1:8444 users:((\"mtg\",pid=101,fd=4))\n" .
    "0 0 [::ffff:192.0.2.1]:8443 [::ffff:198.51.100.2]:50000 users:((\"mtg\",pid=101,fd=5))\n" .
    "0 0 192.0.2.1:50000 198.51.100.3:8445 users:((\"mtg\",pid=101,fd=6))\n"
);
if (($counts['192.0.2.1:8443'] ?? 0) !== 2 || ($counts[8443] ?? 0) !== 2 || isset($counts[8444]) || isset($counts[8445]) || isset($counts[8446]) || isset($counts[8447])) {
    throw new RuntimeException('Peer ports counted as local connections');
}
$summary = getGroupSummary(['self' => null, 'children' => [
    ['online_connections' => 7], ['online_connections' => 0], ['online_connections' => 2]
]]);
if ($summary['online'] !== 2 || $summary['count'] !== 3) {
    throw new RuntimeException('Group must count clients, not connections');
}
echo "Online regression checks passed\n";
