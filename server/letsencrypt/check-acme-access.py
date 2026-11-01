#!/usr/bin/env python3
"""Compare direct/proxied ACME directory access without exposing proxy secrets."""
from pathlib import Path

import requests


def proxy_settings(path):
    values = {}
    allowed = {"http_proxy", "https_proxy", "all_proxy"}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        name, value = line.split("=", 1)
        if name.strip().lower() in allowed:
            values[name.strip()] = value.strip().strip("\"'")
    # Match requests' preference for lowercase environment variables.
    return {scheme: values.get(f"{scheme}_proxy", values.get(f"{scheme.upper()}_PROXY", ""))
            for scheme in ("http", "https", "all")}


def probe(label, url, proxies):
    with requests.Session() as session:
        session.trust_env = False
        session.proxies.update({key: value for key, value in proxies.items() if value})
        try:
            response = session.get(url, timeout=(10, 20))
            response.raise_for_status()
            directory = response.json()
            if not isinstance(directory, dict) or not {"newNonce", "newOrder"} <= directory.keys():
                print(f"{label}: invalid ACME directory", flush=True)
                return
            print(f"{label}: HTTP {response.status_code}; ACME directory OK", flush=True)
        except (requests.RequestException, ValueError) as error:
            # Exception messages can contain credential-bearing proxy URLs.
            print(f"{label}: {type(error).__name__}", flush=True)


def main():
    try:
        proxies = proxy_settings(Path("/etc/monit-telegram.env"))
    except OSError:
        raise SystemExit("STOP: cannot read existing proxy settings") from None
    if not (proxies.get("https") or proxies.get("all")):
        raise SystemExit("STOP: no HTTPS proxy configured")
    for name, host in (("staging", "acme-staging-v02.api.letsencrypt.org"),
                       ("production", "acme-v02.api.letsencrypt.org")):
        url = f"https://{host}/directory"
        probe(f"{name} direct", url, {})
        probe(f"{name} proxy", url, proxies)


if __name__ == "__main__":
    main()
