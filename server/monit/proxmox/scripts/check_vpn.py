#!/usr/bin/env python3
"""Read-only health checks for the Docker WireGuard gateway and relays."""
import argparse
import json
import subprocess
import time


class Unhealthy(Exception):
    pass


def command(*args):
    result = subprocess.run(args, capture_output=True, text=True, timeout=8)
    if result.returncode:
        raise Unhealthy(f"{args[0]} health query failed")
    return result.stdout


def handshake_age(output, now, maximum):
    lines = [line.split() for line in output.splitlines() if line.strip()]
    if len(lines) != 1 or len(lines[0]) != 2:
        raise Unhealthy("expected exactly one WireGuard upstream peer")
    try:
        stamp = int(lines[0][1])
    except ValueError:
        raise Unhealthy("invalid handshake timestamp") from None
    if stamp <= 0:
        raise Unhealthy("WireGuard handshake is missing")
    age = now - stamp
    if age < 0 or age > maximum:
        raise Unhealthy(f"WireGuard handshake age outside limit: {age}s")
    return age


def check_listeners(output, address, ports):
    listeners = set()
    for line in output.splitlines():
        fields = line.split()
        if len(fields) >= 4 and fields[0] == "LISTEN":
            listeners.add(fields[3])
    missing = [str(port) for port in ports if f"{address}:{port}" not in listeners]
    if missing:
        raise Unhealthy("missing WireGuard relay listeners: " + ", ".join(missing))


def check(ports):
    state = json.loads(command("docker", "inspect", "--format", "{{json .State}}", "vpn-gateway"))
    if not isinstance(state, dict) or not state.get("Running") or state.get("Paused"):
        raise Unhealthy("vpn-gateway is not running normally")
    age = handshake_age(
        command("docker", "exec", "vpn-gateway", "wg", "show", "wg0", "latest-handshakes"),
        int(time.time()), 180,
    )
    if command("systemctl", "is-active", "proxmox-gateway-relays.service").strip() != "active":
        raise Unhealthy("relay service is not active")
    output = command("docker", "exec", "vpn-gateway", "ss", "-H", "-lnt")
    check_listeners(output, "10.80.0.10", ports)
    return f"OK: gateway running; handshake age={age}s; relays active; ports=" + ",".join(map(str, ports))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ports", nargs="+", type=int, default=[2222, 8006])
    args = parser.parse_args()
    if any(not 1 <= port <= 65535 for port in args.ports):
        parser.error("ports must be between 1 and 65535")
    try:
        print(check(args.ports))
        return 0
    except Unhealthy as error:
        print(f"ALERT: {error}")
        return 1
    except (OSError, ValueError, TypeError, subprocess.SubprocessError):
        print("ERROR: cannot complete VPN health query")
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
