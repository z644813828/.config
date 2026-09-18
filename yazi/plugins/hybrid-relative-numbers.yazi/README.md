# hybrid-relative-numbers.yazi

Hybrid relative line numbers for Yazi 26.9.1.

- Hovered/current line: absolute 1-based number.
- Other lines in the current pane: distance from the cursor.
- Parent/preview panes are left unchanged.
- Numbers are inserted before the file icon, so normal linemode (size/mtime/etc.) remains available on the right.

## Install

Copy this directory to:

    ~/.config/yazi/plugins/hybrid-relative-numbers.yazi

Then add to `~/.config/yazi/init.lua`:

    require("hybrid-relative-numbers"):setup({
        min_width = 2,
        separator = " ",
    })

Restart Yazi.
