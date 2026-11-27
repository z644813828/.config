# remote-preview.yazi

Preview for remote files (`sftp://` tabs opened with `gs`, see
[remote-connect](../remote-connect.yazi/README.md)) in Yazi 26.9.1.

Yazi keeps a local copy of a remote file only after it has been downloaded.
Until then the file has the MIME type `vfs/absent` (or `vfs/stale` when the
server's copy changed), and the built-in previewer only says "download to
preview". This previewer replaces it:

- Archives (`zip`, `tar.*`, `7z`, `rar`, `jar`, ...) are listed on the server
  over the existing `gs` SSH connection, without downloading them, at any
  size. The server uses the first of `bsdtar`, `7z`/`7zz`, `unzip` (zip) or
  `tar` it has. Scroll the listing like a text preview.
- Other files up to 5 MB are downloaded automatically after the cursor rests on them
  for 0.3 s. Moving on earlier downloads nothing, so scrolling through a
  listing is cheap. When the download finishes, Yazi detects the real MIME type
  and the normal previewer (code, `image-fit`, ...) shows the local copy.
- Larger files show their size; press Enter to download and open them.
  A downloaded archive gets Yazi's normal archive preview.
- Each file version is requested once per session. If a download fails (for
  example while offline), press Enter on the file to retry.

The local copies live in Yazi's temporary directory (`$TMPDIR/yazi-<uid>/`).
`remote-connect` deletes them when the connection is closed, except copies you
edited that have not been uploaded yet.

Configured in `yazi/yazi.toml`:

```toml
[plugin]
prepend_previewers = [
  { mime = "vfs/{absent,stale}", run = "remote-preview" },
]
```

Adjust `LIMIT` and `DELAY` at the top of `main.lua`.
