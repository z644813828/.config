# ranger -> Yazi 26.9.1 migration

Goal: keep the Mac/Yazi keybindings as close as practical to the existing server/ranger rc.conf.

Directly migrated: navigation, history, F-keys, selection/tag-like behavior, personal g* paths,
rename, copy/cut/paste/link/hardlink, delete/trash, clipboard paths, find/filter, tabs,
sorting where Yazi has the same sort type, hidden files, line modes, and archive shortcuts.

Not mapped 1:1 because Yazi has no direct equivalent in 26.9.1:
- ranger arbitrary character tags (`"<any>`), tag-ordered search
- ranger bookmark families (`m<any>`, `'<any>`, `` `<any> ``) and tab_restore
- sort by ctime/atime/type/basename (Yazi supports mtime/btime/extension/alphabetical/natural/size/random)
- toggle sort_reverse as a standalone action
- collapse_preview, preview_files/directories, flushinput, mouse toggle, preview-script toggle
- cumulative-size commands and ranger's hardlinked-subtree paste
- ranger's fzf_select command (Yazi has its own fzf/zoxide integrations; left to defaults)
- exact ranger `display_file` behavior; F3 is mapped to Yazi `spot`

Notes:
- `t` is intentionally overridden from Yazi defaults and acts like ranger tag/selection toggle.
- `i` opens macOS Quick Look for the hovered file.
- Space toggles the hovered selection and advances one row, matching ranger's marking flow.
- `[` and `]` use `plugins/parent-switch.yazi` for ranger-style `move_parent`: when
  `/base/2` is current with `f` hovered, they enter `/base/1` and `/base/3` respectively.
- Ctrl-N creates a tab in the current directory; Tab/Shift-Tab switch tabs.
- Option/Alt bindings require the terminal to send Option as Meta/Alt.
- `q` closes the active tab and exits Yazi only when it was the last tab; `Q`
  exits Yazi explicitly.
- `l`, Enter, and Right use `plugins/smart-enter.yazi`: directories use `enter`,
  while files open the selection, or the hovered file when nothing is selected.
- All openers use Yazi's `%s` file-path placeholder (not shell `$@`), so `l` passes the
  selected paths (or the hovered filename) to `$EDITOR`; `S` opens a blocking `fish` shell.
- `r` prompts for an application command before `%s`; F4 retains the configured opener menu.
- `zh`, Ctrl-H, and Backspace toggle hidden files.
- The full current-directory path and right-aligned tabs share one header row.
- Creation time and the search match counter appear in the status bar. Search highlighting is disabled.
- `theme.toml` uses the Nord palette from the Neovim and iTerm profiles, with square tabs and indicators.
- PDF preview is disabled with the built-in `noop` previewer, so Poppler/`pdftoppm` is not required;
  PDFs still open through the normal macOS opener. Video preview is disabled too, so FFmpeg/`ffprobe`
  is not required; videos still open through the normal macOS opener.
- `1` through `9` start a silent Vim/ranger count for `j`/`k`; more digits (including
  zero) are read by `plugins/vim-count.yazi`, so `3j`, `12k`, and `123j` work without
  a key-indicator popup. A standalone `0` is deliberately left to Yazi's default mapping.
- `DD` is permanent delete with confirmation; `dD` moves to Trash without confirmation.
- `image-fit` enlarges cached image previews on macOS using `sips`; Linux retains standard previews.
- Archive shortcuts require the corresponding command (zip/7z/tar) to exist.
- `l`/Enter/Right on an unselected archive mounts it read-only through
  [archive browser](plugins/archive-browser.yazi/README.md). `h`/Left at its root
  unmounts it and returns to the archive. Requires macFUSE and `ratarmount`.
  The mount is a normal local directory, so previews, `r`, F4 and E use the
  usual Yazi openers directly. `w` shows the initial mount task.
