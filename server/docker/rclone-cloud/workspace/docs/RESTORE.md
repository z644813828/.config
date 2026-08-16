# Encrypted Google Drive Restore

## Preserve Outside This Server

Keep a secure, offline copy of `/root/.config/rclone/rclone.conf`. It contains
the Google OAuth refresh token and the obscured crypt password and salt required
to decrypt the backup. Store it in an encrypted password manager or encrypted
offline archive, with file mode `0600`.

Also preserve access to the Google account and the Google OAuth Desktop client
used for `gdrive_backups`. Losing the crypt configuration means the encrypted
backup cannot be decrypted.

## Configure a Replacement Machine

1. Install a current rclone release.
2. Securely restore the saved configuration to `~/.config/rclone/rclone.conf`.
3. Set permissions: `chmod 600 ~/.config/rclone/rclone.conf`.
4. Confirm the required remotes exist without printing their configuration:

   ```bash
   rclone listremotes
   rclone lsd gdrive_crypt:offsite-backups
   ```

## Restore Data

The only plaintext top-level directory on Google Drive is `rclone`. Everything
below it is addressed through `gdrive_crypt:` and is encrypted client-side.

Choose an empty destination with enough free capacity. `rclone copy` does not
delete files from either side.

```bash
mkdir -p /restore/backup
rclone copy gdrive_crypt:offsite-backups /restore/backup \
  --fast-list --checkers 8 --transfers 4 --retries 3 --low-level-retries 10 \
  --progress
```

## Verify the Restore

Compare the restored directory against the encrypted remote:

```bash
rclone check /restore/backup gdrive_crypt:offsite-backups --one-way
```

For critical restores, also create and compare SHA-256 manifests on the
restored data and an independently retained source manifest.
