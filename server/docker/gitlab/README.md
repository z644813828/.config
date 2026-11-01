# Clean GitLab Installation

The user chose a fresh installation on 2026-10-31. This deployment does not
restore the old GitLab 15.11 instance or attach its existing volumes.

The canonical repository directory and Compose project name are `gitlab`.
Replace `server.example.invalid` with the deployment hostname before use.
This is a fresh-install template, NOT an in-place upgrade from GitLab 15.11.

The running migration deployment was created in a separate directory and
Compose project. Repository renaming does not rename that live deployment.
Do not deploy this file over the legacy `gitlab` directory: it contains the
old 15.11 data. Keep that directory unchanged for rollback. Before any live
rename, stop the current deployment, preserve the legacy directory under a
distinct archive name, and record the current project name and bind sources.
Renaming a directory or changing the project name alone does not migrate a
container. Never initialize empty replacement data or run two GitLab instances
against the same directories. Before a fresh installation, verify that the
Data filesystem is mounted and that no existing container named `gitlab` is
running or stopped. Create empty `config`, `logs` and `data` directories before
running Compose; automatic host-path creation is disabled deliberately.

GitLab CE 19.5.3 is pinned based on the official 2026-10-29 security release:
https://docs.gitlab.com/releases/patches/patch-release-gitlab-19-5-3-released/

Installation and reverse-proxy configuration references:
https://docs.gitlab.com/install/docker/installation/
https://docs.gitlab.com/omnibus/settings/nginx/

The application listens on HTTP 8929, published only on OMV localhost.
An independent host nginx TLS frontend must provide HTTPS 9444 using the
existing certificate. It is not enabled by this compose file. Git SSH is
published on OMV's LAN IP at port 2224; no WAN or WireGuard forwarding is
automatically configured. GitLab 19.2+ uses `gitlab_rails['nginx']` for the
per-application nginx settings.

The first start initializes a new database and can take several minutes.
Use `docker compose ps`, `docker exec gitlab gitlab-ctl status`, and HTTP
checks against `http://127.0.0.1:8929/users/sign_in` before adding the frontend.
Never paste initial root passwords, tokens, `gitlab-secrets.json`, or full
configuration dumps into chat. Configure sign-up restrictions before public
exposure. Restore repositories by pushing the selected branches and tags from
the user's clones, not by importing the old server database.

The reviewed backup script is `../../backups/docker/gitlab/backup-gitlab.sh`.
It resolves config/data bind sources from the actual gitlab container instead of
assuming the old gitlab or new gitlab-fresh directory. It requires sibling
config/data directories on the mounted Data HDD, the deployed docker-compose.yml,
the Backups HDD and an existing nonempty protected encryption key. It runs
gitlab-backup create, requires a newly created application archive, and packages
that plus config/gitlab-secrets.json and Compose. Encrypted output is published
only after OpenSSL succeeds; partial encrypted output is cleaned on failure.

The user deployed and successfully ran this script on OMV on 2026-11-01.
GitLab reported application backup 1793532464_2026_11_01_19.5.3 complete and
the outer encryption command succeeded. Outer-archive decryption/inspection,
cron restoration and a GitLab restore test are still pending. Preserve legacy files
until both new application and config/secrets backups are verified. The outer
archive retains the existing AES-CBC format for compatibility; no key/format
migration or authenticated-encryption guarantee is implied. Recovery requires
the correct GitLab version and the separately protected encryption key.
