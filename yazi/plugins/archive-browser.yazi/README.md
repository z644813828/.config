# Read-only archive browser — Yazi 26.9.1 / macOS

`l`, Enter or Right on an unselected archive mounts it through `ratarmount` and
opens the mount in Yazi's usual columns. This is a real macFUSE filesystem, not
a Lua VFS: Yazi, Quick Look and applications see ordinary read-only files.

`h`/Left at the mounted archive root unmounts it, deletes its private index and
returns to the source archive. `q`/`Q` while inside an archive does the same
cleanup before closing Yazi. Nested archives are supported; mounts are removed
in inside-out order on exit. `w` displays the initial `Mount <archive>` task.

## Requirements

- macFUSE enabled for the current macOS installation;
- `ratarmount`, either on `PATH`, at `~/.local/bin/ratarmount`, or in
  `~/.local/share/ratarmount-venv/bin/ratarmount`;
- Yazi 26.9.1.

No `vfs.toml` entry, `ya` binary, `7zz`, `ar`, Python installation visible to
Yazi, or archive extraction configuration is needed after `ratarmount` itself
works. The plugin deliberately does not enable a write overlay, so the archive
is read-only and is never modified.

## Behaviour and cache

- The first mount builds a `ratarmount` index. For TAR/GZ/XZ files this enables
  random access without extracting every member; later opens can reuse an index
  only for the lifetime of this Yazi session.
- Session mounts and indexes live below `~/.cache/yazi/ratarmount-v1/` and are
  removed after a normal `h`/Left or `q`/`Q` exit. The parent cache directory is
  left in place and stays empty.
- If Yazi or macOS is killed before unmounting, macFUSE may retain a stale
  mount. Remount it once with `ratarmount`'s normal command, then run `umount`
  on that mountpoint before removing the corresponding `session.*` directory.
- Archive support is provided by the installed `ratarmount` backends. TAR and
  compressed TAR are its strongest formats; other archive types depend on its
  optional Python/native backends.
