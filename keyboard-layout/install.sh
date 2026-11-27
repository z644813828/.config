#!/bin/bash
set -euo pipefail
layout_root="$(cd -- "$(dirname -- "$0")" && pwd)"
if [[ "$(uname -s)" != Darwin ]]; then
    echo 'Run this script on macOS (requires iconutil).' >&2
    exit 1
fi
/usr/bin/iconutil -c icns "$layout_root/Russian.iconset" \
    -o "$layout_root/RussianCustom.bundle/Contents/Resources/РУ.icns"
/usr/bin/plutil -lint "$layout_root/RussianCustom.bundle/Contents/Info.plist"
mkdir -p "$HOME/Library/Keyboard Layouts"
/usr/bin/ditto "$layout_root/RussianCustom.bundle" \
    "$HOME/Library/Keyboard Layouts/RussianCustom.bundle"
# Remove only the obsolete artifacts created during icon experiments.
/bin/rm -rf "$HOME/Library/Keyboard Layouts/RussianVariants.bundle"
/bin/rm -f \
    "$HOME/Library/Keyboard Layouts/Russian.keylayout" \
    "$HOME/Library/Keyboard Layouts/Russian.icns" \
    "$HOME/Library/Keyboard Layouts/RussianCustom.bundle/Contents/Resources/Russian Custom.keylayout" \
    "$HOME/Library/Keyboard Layouts/RussianCustom.bundle/Contents/Resources/Russian Custom.icns" \
    "$HOME/Library/Keyboard Layouts/RussianCustom.bundle/Contents/Resources/Info.plist"
echo 'Installed. Log out and back in, then select РУ.'
