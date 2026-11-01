# Proxmox VPN Monitoring

Install `scripts/check_vpn.py` in `/etc/monit/scripts/` and
`conf.d/vpn-gateway.conf` in `/etc/monit/conf.d/` on Proxmox, not OMV.
Run the script manually before enabling the check and validate with `monit -t`.
The old source name `check_proxmox_vpn.py` was shortened to `check_vpn.py`;
deploy the renamed script together with the updated configuration. Existing
containers, relay units and Monit service IDs keep their names.

The script checks the existing vpn-gateway container, the single upstream
WireGuard peer's handshake (maximum age 180 seconds), the relay systemd service,
and exact TCP listener bindings at 10.80.0.10 inside the container's network
namespace via its `ss` command. No restarts or network reconfiguration occur.
It does not call the old container check, which could restart WireGuard and
tested obsolete service ports. Docker access uses the host daemon socket; no
extra Monit capabilities are needed or proposed.

The initial explicit required ports are 2222 and 8006 (Proxmox management).
Add application ports to `--ports` only after reviewing the live relay script;
do not assume all repository relay mappings have been deployed. Listener checks
do not prove the destination applications or remote VPS forwarding are healthy.
No keepalive/ping packet is sent by the checker. It relies on the configured
WireGuard persistent keepalive and does not verify remote client connectivity.

Monit checks every 30 seconds and alerts after three failed executions; the
global Telegram recipient handles recovery and reminders. On 2026-11-01 the
target's Monit check was verified as Monitored / OK, exit 0: gateway running,
handshake age 106 seconds, relays active, and listeners 2222/8006 present.
No disruptive failure/recovery or remote-client test was performed for this
VPN check; generic Monit-to-Telegram failure/recovery delivery was verified
separately.
