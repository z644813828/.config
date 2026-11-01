#!/bin/bash

set -euo pipefail

if ! changes=$(/usr/bin/etckeeper vcs status --porcelain 2>/dev/null); then
    echo "ERROR: cannot read etckeeper repository"
    exit 2
fi

if [ -n "$changes" ]; then
    echo "WARNING: /etc contains uncommitted changes; inspect locally"
    exit 2
fi

echo "OK: /etc changes are committed"
