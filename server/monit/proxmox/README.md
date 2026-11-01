# Proxmox Monit

Host checks are in [conf.d/](conf.d/), check scripts and tests in
[scripts/](scripts/). [VPN monitoring](VPN.md) is documented separately.
[UPS portal integration](UPS-PORTAL.md) uses a restricted SSH reader from OMV.
AppArmor and systemd support files remain in this directory and are installed
to their respective host configuration directories, not into Monit conf.d.

## Disk Temperature Notifications

Host-side Monit checks use smartmontools JSON, not guest QEMU disk statistics.
There is no web endpoint, dashboard, Docker socket mount, or inbound port.
Send Monit mail to the separate host Docker Telegram bridge on localhost:2525.
That bridge must have its own bot token, queue and working authenticated proxy.
Never reuse the OMV bot token or consume its Telegram updates from the host.

## Policy

- Warning: SATA HDD >=50 C; SATA SSD >=60 C, after two failed check executions.
- Critical: SATA HDD >=55 C; SATA SSD >=70 C, on the first failed execution.
- These are configurable operational thresholds, not manufacturer limits.
- Checks run every two Monit cycles; at 30 seconds per cycle that is about a minute.
- Monit handles failure/recovery events and hourly reminders (120 base cycles).
- SMART read failures alert too. SMART health and disk-disappearance monitoring
  are separate concerns, not covered by a successful temperature check.
- Only directly attached SATA disks are included. USB, NVMe and virtual disks
  are deliberately excluded rather than queried with guessed transport options.
- `smartctl -d sat -n standby,3,5` avoids transport autodetection and skips low
  power drives. Unsupported power checks fail closed rather than spin up a disk.
- The current temperature is read from `temperature.current`, never historical
  maxima, normalized attribute values, or packed raw integers.
- A sleeping disk's last hot reading is retained, keyed by serial, so sleep does
  not cause a false recovery. Monit recovery requires a successful check with
  all checked disks below the relevant threshold and no retained hot reading.
- Per-level cache files are locked and atomically replaced under /var/lib/monit.

## Deployment

First validate both levels manually as root on Proxmox. Exit codes are 0 for
no detected over-temperature, 1 for overheating, and 2 for collection errors.
Compare every active physical disk against the initial smartctl inventory.

Install `scripts/check_disk_temperatures.py` root-owned at `/etc/monit/scripts/check_disk_temperatures.py`
with mode 0750. Use the packaged Monit configuration; do not copy OMV-generated
filesystem/process checks onto Proxmox. Configure host SMTP delivery and verify
the Telegram test before enabling alerts. The separate host bot's `getMe`
request through the proxy succeeded on 2026-11-01 after earlier HTTP 502 errors.
Chat discovery and bridge replacement were subsequently completed; the user
confirmed a host SMTP test message arrived in the separate Telegram bot.
The user also confirmed both Monit-generated failure and recovery test alerts.
UPS-state alert delivery and actual battery-triggered shutdown remain untested.

After saving the private chat ID in `/etc/monit-telegram.env`, run
`scripts/start-telegram.sh` as root on Proxmox. It uses the restored image without
pulling or rebuilding, a dedicated persistent queue volume, host networking,
and the same read-only/capability restrictions as the OMV bridge. It refuses
to replace an existing container. SMTP must listen only on 127.0.0.1:2525.
Verify delivery with a test SMTP message before enabling host Monit alerts.

The first host bridge launch failed before SMTP startup: kernel audit confirmed
`docker-default` denied AF_UNIX stream creation (`failed protocol match`).
Install `monit-telegram.apparmor` as `/etc/apparmor.d/proxmox-monit-telegram`
and load it with `apparmor_parser -r` before starting the bridge. This separate
Moby-derived profile explicitly permits Unix IPC while retaining the baseline
proc/sys/mount denies. Initial socket tests failed. Inspection then showed the
target's ABI directive was commented out (`# abi <abi/3.0>,`), so the explicit
ABI variant had not actually been tested. Keep `abi <abi/3.0>,` uncommented
before the tunables include, reload the profile and repeat the socket test.
After uncommenting the directive, the target's isolated socketpair and asyncio
test succeeded. The replacement bridge's SMTP-to-Telegram test also succeeded.
Before replacement, stop the old bridge and rename it (for example to
`monit-telegram-before-apparmor-YYYYmmdd-HHMMSS`), then run `scripts/start-telegram.sh`.
Reuse `proxmox-monit-telegram-queue`; never run both containers against it.
ABI pinning was investigated based on the upstream issue at
https://github.com/containerd/containerd/issues/12726 . Inspect fresh audit
records, the installed profile, parser version and ABI overrides before further
changes. Do not modify the global parser ABI, docker-default globally, or
disable seccomp.
First verify socketpair and asyncio creation in an isolated temporary container
using the profile, without credentials or queue mounts. The old stopped bridge
and its queue must be retained until the replacement is verified.

Install `conf.d/telegram.conf` as `/etc/monit/conf.d/00-telegram.conf` after inspecting
the host's active include and notification directives for conflicts. Keep Monit
masked during initial configuration. Do not expose its HTTP interface on a
network address just to enable notifications.

The target package was installed masked; its conf.d directory was empty and
monitrc included conf.d/* and conf-enabled/*. Change its existing daemon interval
from 120 to 30 seconds (do not add a duplicate). Install `conf.d/local-interface.conf`
for a root-only Unix control socket and `conf.d/apcupsd.conf` for daemon/NIS listener
monitoring. This check does not detect battery states; `conf.d/ups-status.conf` adds
read-only polling instead of custom APC event hooks. Do not auto-restart apcupsd
from Monit during setup.
The Unix HTTP block must include `allow localhost`: without an allow directive,
Monit logs "httpd not started since no connections are allowed" and never
creates the socket. Keep mode 0600 and do not add a TCP port.
The global alert recipient carries the 120-cycle reminder; program checks must
not contain standalone reminder directives.

For the Debian Monit unit's capability sandbox, install `smart-access.conf` as
`/etc/systemd/system/monit.service.d/smart-access.conf` to add CAP_SYS_RAWIO while
preserving the existing capabilities. Reload systemd and restart Monit. Wait
for any configured start delay, then verify reads from Monit's actual execution
context and inspect its journal. Do not disable the rest of the service sandbox.

Install `conf.d/disk-temperatures.conf` under `/etc/monit/conf.d/` only after configuring
the global SMTP target and alert recipient. Validate with `monit -t`, reload,
and check both programs' results. Test alerts without heating physical drives
by using a temporary failing Monit check, then changing it to succeed. Verify
both failure and recovery messages before removing that temporary check.

The user selected notifications only; do not add temperature data to the portal.

## Target SMART Permission Issue

The first service-context checks returned SLEEP for all eight disks and reused
cached temperatures despite showing OK. A root `smartctl -d ata` check read
the active system SSD at 30 C, while the same command in a transient service
with Monit's capabilities (including CAP_SYS_RAWIO) falsely reported SLEEP.
Do not interpret those initial OK results as fresh readings. A subsequent
explicit `smartctl -d sat` check under the same restricted capabilities returned
the system SSD's current 30 C temperature successfully. The collector now uses
SAT without adding CAP_SYS_ADMIN. On 2026-11-01 the user verified fresh readings
for all eight disks from both Monit checks: 30, 40, 33, 32, 38, 33, 32 and 32 C.
Both checks exited 0. Actual standby preservation has not been discharge-tested
or validated by deliberately spinning down a disk.

## UPS State Notifications

Install `scripts/check_ups_status.py` as
`/etc/monit/scripts/check_ups_status.py` and `conf.d/ups-status.conf` in conf.d.
The script only reads `/sbin/apcaccess status 127.0.0.1:3551`, with an 8-second
timeout. ONLINE (including BOOST/TRIM) is healthy; battery or fault states alert,
as do communication/parse errors. At the 30-second daemon interval, transitions
may take a cycle to be detected; short outages between polls may be missed.
Global Telegram failure/recovery delivery is used. No custom shutdown hook is
installed, and automatic shutdown does not depend on Monit or notifications.

## Non-Disruptive Notification Test

After Monit starts, install `notification-test.conf.example` temporarily as
`/etc/monit/conf.d/notification-test.conf`. First ensure the marker
`/var/lib/monit/notification-test.ok` is absent, then validate and reload Monit.
Wait for a failure notification. Create the marker and wait for a recovery
notification. Check `monit status notification_test`, remove the temporary
configuration, validate and reload, and finally remove the marker. Do not
simulate failure by stopping apcupsd or disconnecting UPS power.

## Tests

From the repository root:

```bash
python3 -B -m unittest discover -s server/monit/proxmox/scripts -p 'test_*.py'
```
