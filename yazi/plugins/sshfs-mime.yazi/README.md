# sshfs-mime.yazi

MIME fetcher for SSHFS mounts created by
[remote-connect](../remote-connect.yazi/README.md), Yazi 26.9.1. It guesses
the type from the file name and never reads file contents.

## Why

Yazi's default `mime.local` fetcher runs `file` on every entry of a directory,
and `file` reads the start of each file. On SSHFS that is one network read per
file: remote directories fill in slowly, and closing the tab while those
fetcher tasks are still running asks "There are unfinished tasks, quit
anyway?".

## Rules

- empty file → `inode/empty`;
- no extension → `text/plain` (on servers these are mostly configs and
  scripts, so they open in `$EDITOR` and get a text preview);
- known extension → its type from the table in `main.lua` (text and code,
  images, audio/video, archives, PDF, common binaries);
- unknown extension → `application/octet-stream`.

Directories are not handled here: the pattern has no trailing `/`, so Yazi's
built-in `mime.dir` still covers them.

A guess can be wrong, for example a binary without an extension is treated as
text. Add the extension to `EXT` in `main.lua` when that matters.

## Configuration

Enabled in `yazi/yazi.toml` for mount paths only; local directories keep the
default `mime.local`:

```toml
[plugin]
prepend_fetchers = [
  { url = "**/yazi/sshfs-v1/session.*/mount/**", run = "sshfs-mime", prio = "high", group = "mime" },
]
```

If `remote-connect` changes its mount directory, update this pattern too.
