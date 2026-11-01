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
`Host *`; its `User` and `Port` are prefilled, and `HostName` is resolved by SSH.
The plugin also reads a custom `#Password` comment in matching `Host` blocks
of `~/.ssh/config` (first matching value wins; wildcard/negated hosts are supported).
For example:

```sshconfig
Host example
    User root
    #Password password
    HostName 192.168.1.1
    Port 22
```

The password prompt is prefilled from the value remembered for this host,
login and port, or from `#Password` on first use. Editing it replaces the value
in Yazi's memory. Leave it empty to use an SSH key.

Yazi 26.9.1 has no completion for plugin inputs, so the host prompt drives
the built-in completion popup (`cmp:trigger`) itself. The popup lists
directory entries, so the aliases are mirrored as empty files in
`~/.cache/yazi/ssh-hosts/` while the prompt is open; the directory is removed
after a host is chosen or the prompt is cancelled.

## Keys

The `g` key opens a context-dependent menu. SSHFS tabs offer `gh` and `g/`
to go to the mount root, `gg` to go to the top of the list, and `gt`/`gT`
for the next/previous tab.
All other `g` combinations are disabled and omitted from that menu,
including `gs` and `g<Space>`.
Use Tab/Shift-Tab to switch tabs and Ctrl-T to open a local tab.
Local tabs retain the full menu, including all personal directory shortcuts.
The SSHFS association belongs to the tab even if it navigates outside the
mount. Duplicated tabs share the association; closing one keeps the mount
while another tab owns it. Menu actions are defined in `g_menu` in `main.lua`.

| Key | Action |
| --- | --- |
| `g` then `s` | Asks for a host with the same completion popup as `g<Space>`, listing `~/.ssh/config` aliases (type to filter, Tab/Enter to complete; a host or IP that matches nothing is used as typed), then prompts for login, password, port and remote path. The path accepts `/absolute/path`, `~`, and `~/path`. |
| `S` | Open a terminal in the current directory, using Fish if available, otherwise `$SHELL` (or `/bin/sh`). On an SSHFS tab both the directory and shell are on the remote server. |
| `s` | On an SSHFS tab, open the same remote terminal as `S`. Locally, retain Yazi's interactive shell-command prompt. |
| `Ctrl-N` | Create a tab at exactly the current directory, including inside an existing SSHFS mount. |
| `q` / `Ctrl-F4` | Close the tab. An SSHFS mount is unmounted only when no other tab uses it. Closing the final tab cleans all mounts and exits. |
| `Q` / `F10` | Quit Yazi after cleaning every SSHFS mount created by Yazi, including mounts in other tabs. |

The password prompt is obscured. Entered passwords live only in Yazi's memory
until it exits, and are reused by `s`/`S` through `sshpass -e`. They are never
written to session files or shell command text. The plugin does not modify
`~/.ssh/config`; a `#Password` you put there remains a plain-text comment.

Before mounting or opening a terminal, credentials are checked without giving
SSH access to Yazi's terminal. Key authentication uses `BatchMode=yes`; password
authentication allows one attempt through `sshpass`. Authentication failures
do not open a background password prompt. Unknown or changed host keys are
rejected (`StrictHostKeyChecking=yes`); add/verify the host in a normal SSH
terminal first. These controls follow the [OpenSSH options](https://man.openbsd.org/ssh_config).

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
