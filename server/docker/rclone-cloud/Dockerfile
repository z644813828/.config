FROM debian:11-slim

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        openssh-server \
        unzip \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /run/sshd /root/.ssh \
    && chmod 700 /root/.ssh \
    && printf '%s\n' \
        'PermitRootLogin prohibit-password' \
        'PasswordAuthentication no' \
        'KbdInteractiveAuthentication no' \
        'UsePAM no' \
        > /etc/ssh/sshd_config.d/rclone-cloud.conf

ENV TZ=Europe/Moscow

RUN ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime \
    && echo "$TZ" > /etc/timezone

RUN set -eux; \
    tmpdir="$(mktemp -d)"; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        amd64) rclone_arch=amd64 ;; \
        arm64) rclone_arch=arm64 ;; \
        *) echo "Unsupported architecture: $arch" >&2; exit 1 ;; \
    esac; \
    curl -fsSLo "$tmpdir/rclone.zip" "https://downloads.rclone.org/rclone-current-linux-${rclone_arch}.zip"; \
    unzip -q "$tmpdir/rclone.zip" -d "$tmpdir"; \
    install -m 0755 "$tmpdir"/rclone-*/rclone /usr/local/bin/rclone; \
    rm -rf "$tmpdir"

CMD ["/usr/sbin/sshd", "-D", "-e"]
