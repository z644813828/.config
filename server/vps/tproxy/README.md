# Per-profile online status

The panel reads live WebProxy session counts from the loopback-only admin endpoint
`http://127.0.0.1:8081/profile-stats`. JSON maps profile names to counts, including
zero for idle profiles. It contains no secrets, tokens or client addresses.
Do not proxy the admin listener through nginx.

`profile-stats.patch` applies to official upstream commit
[`c8adb8b7c6b7fc46c12ae3acb68be9070c26a8e8`](https://github.com/telegramdesktop/tproxy-server/tree/c8adb8b7c6b7fc46c12ae3acb68be9070c26a8e8).
The downloaded master archive had SHA-256
`a65c21c512873803236b09b70ad637a33a45844d6924a7c3dbb90f24a3a58754`;
its tar PAX comment identified that commit. Use the pinned commit, not a future master.

From the upstream source directory:

```bash
patch -p1 < /path/to/profile-stats.patch
CGO_ENABLED=0 go test ./...
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -o tproxy-server ./cmd/tproxy-server
```

Build toolchain: Go 1.27.3. Tests cover session creation/closure, idle profiles,
snapshot isolation and public/admin separation. Replace the binary atomically,
retain its previous version and restart tproxy-server. Clients reconnect after restart.

Panel status combines direct MTG ESTABLISHED sockets (local address and port only)
with live WebProxy sessions. Group counters count profiles, not connections.
If telemetry is unavailable and no direct connection exists, the panel shows
“Нет данных” rather than “Офлайн”. This measures proxy connectivity, not Telegram
user presence. After an unclean disconnect, relay sessions remain counted until
the configured idle timeout expires.

Direct sockets must be owned by an MTG process; established sockets still waiting
in the kernel accept queue are excluded. The last-activity timestamp is never
synthesized from an open connection. It shows the MTProto traffic collector
observation (default threshold: 64 KiB per collection interval); per-profile
WebProxy traffic timestamps are not currently available.
