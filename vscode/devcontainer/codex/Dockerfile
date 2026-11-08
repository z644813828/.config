FROM mcr.microsoft.com/devcontainers/base:trixie

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    g++ \
    cmake \
    cmake-data \
    ninja-build \
    gdb \
    pkg-config \
    vim \
    git-delta \
    docker.io \
    clangd \
    ripgrep \
    fd-find \
    jq \
    fzf \
    grep \
    sed \
    gawk \
    ca-certificates \
    qtbase5-dev \
    libqt5xmlpatterns5 \
    libqt5xml5 \
    && ln -sfn /usr/bin/fdfind /usr/local/bin/fd \
    && ln -sfn /usr/bin/batcat /usr/local/bin/bat \
    && cmake_version="$(/usr/bin/cmake --version | awk 'NR==1{print $3}' | cut -d. -f1,2)" \
    && ln -sfn "/usr/share/cmake-${cmake_version}" /usr/share/cmake-current \
    && printf '%s\n' '#!/usr/bin/env bash' 'export CMAKE_ROOT=/usr/share/cmake-current' 'exec /usr/bin/cmake "$@"' > /usr/local/bin/cmake \
    && chmod +x /usr/local/bin/cmake \
    && cmake --version \
    && cmake -E capabilities >/dev/null \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/vscode/.vscode-server/extensions /home/vscode/.vscode-server/extensionsCache \
    && chown -R vscode:vscode /home/vscode/.vscode-server
