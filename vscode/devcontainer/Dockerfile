FROM debian:trixie

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV TZ=Europe/Moscow

RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https apt-utils \
    bash-completion bat build-essential bzip2 \
    ca-certificates clang-tidy clangd cmake \
    curl dialog dirmngr docker.io fd-find fish fzf \
    g++ gawk gcc gdb gettext git gnupg \
    grc grep htop iproute2 jq less \
    libc6-dev libcurl4-openssl-dev libexpat1-dev \
    libgssapi-krb5-2 libkrb5-dev libpcre2-dev \
    libssl-dev locales lsb-release lsof \
    man-db manpages manpages-dev nano ncdu \
    neovim net-tools ninja-build pkg-config \
    procps psmisc qtbase5-dev ranger ripgrep \
    sed silversearcher-ag ssh strace sudo \
    tar tree unzip vim xz-utils zip zlib1g-dev zsh \
    python3 python3-pip python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash vscode \
    && echo 'vscode ALL=(ALL) NOPASSWD:ALL' \
       > /etc/sudoers.d/vscode \
    && chmod 0440 /etc/sudoers.d/vscode \
    && mkdir -p /workspace /vscode \
       /home/vscode/.codex \
       /home/vscode/.codex-shared \
       /home/vscode/.vscode-server/extensions \
       /home/vscode/.vscode-server/extensionsCache \
    && chown -R vscode:vscode /home/vscode /workspace /vscode \
    && ln -s /usr/bin/batcat /usr/local/bin/bat \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd

WORKDIR /workspace
CMD ["/bin/bash"]

