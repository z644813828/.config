# smart-enter.yazi

Ranger-like right motion for Yazi 26.9.1:

- directory → `enter`
- file → opens the current selection when one exists; otherwise the hovered
  file

`init.lua` enables `open_multi`, so `l`, Enter, and Right pass all selected
files to the configured opener. Set it to `false` to always open only the
hovered file.
