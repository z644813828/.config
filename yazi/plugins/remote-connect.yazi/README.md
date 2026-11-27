# remote-connect.yazi

Interactive, read-write SFTP connections for Yazi 26.9.1 on macOS. It asks for
the server when needed and opens it in a new Yazi tab through Yazi's built-in
SFTP client. Nothing is mounted into the macOS filesystem, so a lost
connection cannot stall Finder, Quick Look or other programs.

## Requirements

- OpenSSH (`ssh`, `ssh-keygen`, `/usr/sbin/sshd`), included with macOS
- optionally `sshpass`, only when logging in with a password rather than an
  SSH key

```sh
command -v sshpass  # needed only for password authentication
```

The server must be reachable from a normal terminal first: unknown or changed
host keys are rejected (`StrictHostKeyChecking=yes`), so add/verify the host
with a plain `ssh` once.

## Choosing a server

Aliases from `~/.ssh/config` are offered in the initial picker; a host or IP
that matches no alias is used as typed. Selecting an alias uses `ssh -G` to
resolve the effective configuration, including `Include` and `Host *`; its
`User` and `Port` are prefilled, and `HostName`, `IdentityFile`, `ProxyJump`
etc. are applied by SSH itself.

The plugin also reads a custom `#Password` comment in matching `Host` blocks
of `~/.ssh/config` (first matching value wins; wildcard/negated hosts are
supported). For example:

```sshconfig
Host example
    User root
    #Password password
    HostName 192.168.1.1
    Port 22
```

The password prompt is prefilled from the value remembered for this host,
login and port, or from `#Password` on first use. Editing it replaces the value
in Yazi's memory. Leave it empty to use an SSH key or the SSH agent.

Yazi 26.9.1 has no completion for plugin inputs, so the host prompt drives
the built-in completion popup (`cmp:trigger`) itself. The popup lists
directory entries, so the aliases are mirrored as empty files in
`~/.cache/yazi/ssh-hosts/` while the prompt is open; the directory is removed
after a host is chosen or the prompt is cancelled.

## Keys

The `g` key opens a context-dependent menu. Remote tabs offer `gh` and `g/`
to go to the connection root, `gg` to go to the top of the list, and `gt`/`gT`
for the next/previous tab. All other `g` combinations are disabled and omitted
from that menu, including `gs` and `g<Space>`. Use Tab/Shift-Tab to switch tabs
and Ctrl-T to open a local tab. Local tabs retain the full menu, including all
personal directory shortcuts. Menu actions are defined in `g_menu` in `main.lua`.

| Key | Action |
| --- | --- |
| `g` then `s` | Asks for a host with the same completion popup as `g<Space>`, listing `~/.ssh/config` aliases (type to filter, Tab/Enter to complete), then prompts for login, port, password and remote path, and opens the server in a new tab named `sftp:<host>`. The path accepts `/absolute/path`, `~`, and `~/path`. |
| `S` | Open a terminal in the current directory, using Fish if available, otherwise `$SHELL` (or `/bin/sh`). On a remote tab both the directory and shell are on the server. |
| `s` | On a remote tab, open the same remote terminal as `S`. Locally, retain Yazi's interactive shell-command prompt. |
| `Ctrl-N` | Create a tab at exactly the current directory, local or remote. |
| `q` / `Ctrl-F4` | Close the tab. The SSH connection is dropped when no other tab uses it. Closing the final tab drops all connections and exits. |
| `Q` / `F10` | Drop every connection, stop the local bridge and quit Yazi. |

The password prompt is obscured. Entered passwords live only in Yazi's memory
until it exits; one is handed to `sshpass -e` to open the connection, and to
`s`/`S` only if that connection is gone. Passwords are never written to files
or shell command text. The plugin does not modify `~/.ssh/config`; a
`#Password` you put there remains a plain-text comment.

Credentials are checked without giving SSH access to Yazi's terminal. Key
authentication uses `BatchMode=yes`; password authentication allows one attempt
through `sshpass`. Authentication failures do not open a background password
prompt. These controls follow the [OpenSSH options](https://man.openbsd.org/ssh_config).

## How it works

Yazi 26.9.1 has a built-in SFTP provider, but on its own it cannot connect to
an arbitrary server. Checked against the 26.9.1 sources
(`yazi-config/src/vfs/sftp.rs`, `yazi-vfs/src/engine/sftp/conn.rs`):

- Services are read once from `vfs.toml` at startup, each with a fixed `host`,
  `user` and `port`. There is no Lua API to add a server at runtime.
- Password authentication takes only a plain-text `password` from `vfs.toml`.
- `~/.ssh/config` is not consulted.
- The server host key is not verified (`check_server_key` accepts every key).
- Timeouts are bounded: SSH keepalive every 10 s, 60 s inactivity timeout,
  45 s per SFTP request and 45 s to obtain a pooled connection.

The plugin therefore gives Yazi a few static "slots" (`sftp://rc1`-`rc4`) that
point at a private bridge, and connects each slot to the server chosen in `gs`:

```text
Yazi sftp://rc1 -> 127.0.0.1:22101 (sshd as you, loopback only)
     -> bridge -> ssh -S <master socket> -> server
```

- The connection to the server is a normal OpenSSH master (`ssh -M`), so
  `~/.ssh/config`, keys, the SSH agent and `StrictHostKeyChecking=yes` apply
  exactly as in a terminal. All of Yazi's SFTP sessions, and `s`/`S`, share
  that one TCP connection.
- The local sshd (`/usr/sbin/sshd`, run as you, no root) listens only on
  127.0.0.1:22101-22104, accepts only Yazi's generated key from loopback, and
  can run only the bridge (`ForceCommand`, `restrict`; no shell, TTY or
  forwarding).
- If the link drops, `ServerAliveInterval=10`/`ServerAliveCountMax=3` end the
  connection after about 40 s; requests in flight then fail. Afterwards, the
  bridge makes one direct attempt per new request: key/agent hosts reconnect
  when the network is back; password hosts fail fast and need `gs` again.
- Up to four connections at once.

## First use and files

On first use, `gs` appends the `rc1`-`rc4` slots to `~/.config/yazi/vfs.toml`
(see [vfs.toml.example](../../vfs.toml.example)) and asks you to restart Yazi
once, because Yazi reads `vfs.toml` only at startup. Restart every running
Yazi instance; `gs` refuses to connect until the slots are loaded.

Keys, the sshd config, logs and control sockets live in
`~/.cache/yazi/sftp-v1` (mode 0700). If a connection is refused, check
`sshd.log`, `rcN/master.log` and `rcN/bridge.log` there.

Your login shell runs the bridge, so it must not print anything when started
non-interactively; any output corrupts SFTP ("Received message too long").
The local sshd passes Yazi's `PATH` to the session (`SetEnv`), so startup
files find the same tools as in a terminal, and it restarts by itself when
that generated config changes. Before opening a tab, `gs` checks the whole
chain with a real SFTP handshake; if your shell prints something, the error
quotes it. The same rule applies to the remote user's shell on the server.

## Previews and local copies

Yazi previews and opens a remote file through a local copy that it downloads
first. [remote-preview](../remote-preview.yazi/README.md) downloads files up to
5 MB automatically when the cursor rests on them, and lists archives on the
server without downloading them; larger files are downloaded with Enter. Yazi uploads an edited copy back to the server by itself.

The copies live in Yazi's temporary directory (`$TMPDIR/yazi-<uid>/`, one
directory per slot), and Yazi never deletes them. This plugin deletes a slot's
copies when its connection is dropped (`q` on the last tab using it, `Q`, or
reuse of the slot by `gs`). A copy counts as in sync when it is unchanged
since download (its size and mtime still match the stamp Yazi wrote, which
does not depend on the server's clock) or when it was uploaded after its last
edit. Anything else may hold an edit that never reached the server (for
example an upload that failed while offline): it is kept, and a warning shows
where. Unfinished downloads (`.*.%tmp`) are always removed.

Not checked yet: opening remote files in external applications (`l`, `r`,
`E`) and archive browsing on `sftp://` tabs.

## Configuration

The plugin is initialised by `yazi/init.lua` and its bindings are in
`yazi/keymap.toml`. Keep the directory name `remote-connect.yazi`: Yazi loads
it as `require("remote-connect")`.
