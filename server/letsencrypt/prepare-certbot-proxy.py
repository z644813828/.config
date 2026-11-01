#!/usr/bin/env python3
"""Copy only proxy settings into a private Certbot EnvironmentFile."""
import os
from pathlib import Path
from urllib.parse import urlsplit


def environment(source):
    values = {}
    for line in source.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip().strip("\"'")
    proxy = values.get("https_proxy", values.get("HTTPS_PROXY", ""))
    if not proxy or any(c.isspace() or c in "\"'\\" for c in proxy):
        raise ValueError("invalid proxy value")
    parsed = urlsplit(proxy)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("invalid proxy URL")
    parsed.port  # Validate a supplied port without displaying the URL.
    lines = [f"{key}={proxy}" for key in
             ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "http_proxy", "https_proxy", "all_proxy")]
    lines += [f"{key}=localhost,127.0.0.1,::1" for key in ("NO_PROXY", "no_proxy")]
    return "\n".join(lines) + "\n"


def main():
    if os.geteuid() != 0:
        raise SystemExit("STOP: run as root")
    target = Path("/etc/letsencrypt/proxy.env")
    try:
        content = environment(Path("/etc/monit-telegram.env").read_text())
        # Exclusive creation avoids overwriting existing settings or symlinks.
        fd = os.open(target, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as output:
            output.write(content)
    except FileExistsError:
        raise SystemExit("STOP: Certbot proxy file already exists; not overwritten") from None
    except (OSError, ValueError):
        raise SystemExit("STOP: cannot prepare proxy settings; values hidden") from None
    print("OK: /etc/letsencrypt/proxy.env created, mode 0600; no Telegram token copied")


if __name__ == "__main__":
    main()
