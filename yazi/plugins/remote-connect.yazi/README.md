# remote-connect.yazi

Interactive, read-write SSHFS connections for Yazi 26.9.1 on macOS.  Unlike
Yazi's static remote configuration, it asks for the server when needed and
opens the mount in a new Yazi tab.

## Requirements

- [macFUSE](https://macfuse.github.io/)
- `sshfs`
- optionally `sshpass`, only when logging in with a password rather than an
  SSH key

Check that the commands are available before launching Yazi:

```sh
command -v sshfs
command -v sshpass  # needed only for password authentication
```

`sshfs` must be able to connect to the host from a normal terminal first.
Aliases from `~/.ssh/config` are offered in the initial picker. Selecting one
uses `ssh -G` to resolve the effective configuration, including `Include` and
`Host *`; its `User` and `Port` are prefilled. Leave the password empty to use
an SSH key.

Yazi 26.9.1 has no completion for plugin inputs, so the host prompt drives
the built-in completion popup (`cmp:trigger`) itself. The popup lists
directory entries, so the aliases are mirrored as empty files in
`~/.cache/yazi/ssh-hosts/` while the prompt is open; the directory is removed
after a host is chosen or the prompt is cancelled.

## Keys

| Key | Action |
| --- | --- |
| `g` then `s` | Asks for a host with the same completion popup as `g<Space>`, listing `~/.ssh/config` aliases (type to filter, Tab/Enter to complete; a host or IP that matches nothing is used as typed), then prompts for login, password, port and remote absolute path. |
| `S` | Open a terminal in the current directory. On an SSHFS tab it connects to the matching directory on the server; locally it opens Fish. |
| `q` / `Ctrl-F4` | Close the tab. For an SSHFS tab it first leaves the mount, unmounts it, then closes the tab. |
| `Q` / `F10` | Quit Yazi, cleaning up the current SSHFS mount first. |

The password prompt is obscured. Its value is passed only to the short-lived
`sshpass` process and is not written to the session directory. Prefer SSH keys
where possible.

## Behaviour and cleanup

Each connection is mounted below:

```text
~/.cache/yazi/sshfs-v1/session.*/mount
```

The plugin opens that `mount` directory in a newly created tab named
`sshfs:<host>`, so remote tabs stand out in the tab bar. It enables
`follow_symlinks`, so absolute symlinks on the remote host resolve on the
remote host instead of appearing to point into the Mac's root filesystem.

Always leave a remote tab with `q`, `Ctrl-F4`, `Q`, or `F10`; this gives macFUSE
a chance to unmount it and remove its session directory. If Yazi or the
terminal is killed, a stale mount may remain. Inspect it with:

```sh
mount | grep "$HOME/.cache/yazi/sshfs-v1"
```

Then unmount the exact `.../mount` path reported there:

```sh
umount /Users/you/.cache/yazi/sshfs-v1/session.XXXXXXXX/mount
# If macOS reports it busy:
diskutil unmount force /Users/you/.cache/yazi/sshfs-v1/session.XXXXXXXX/mount
```

After it is unmounted, the corresponding `session.*` directory can be removed
if it is still present.

## Configuration

The plugin is initialised by `yazi/init.lua` and its bindings are in
`yazi/keymap.toml`. Keep the directory name `remote-connect.yazi`: Yazi loads
it as `require("remote-connect")`.

## MIME types on mounts

Files on the mounts get their MIME type from
[sshfs-mime](../sshfs-mime.yazi/README.md) (by extension) instead of Yazi's
`file`-based fetcher, which would read every file over the network.
