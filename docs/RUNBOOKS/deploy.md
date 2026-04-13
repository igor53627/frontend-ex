# Deploy Runbook

This runbook describes the operational procedure to deploy `frontend-ex`.

## Targets

- Host: `<server>`
- App path: `/path/to/frontend-ex`
- Service: `frontend-ex` (systemd)
- Reverse proxy: Caddy (podman)

## Deploy

Run from your local machine:

```bash
FX_DEPLOY_SERVER=<server> \
FX_DEPLOY_PATH=/path/to/frontend-ex \
FX_SERVICE_NAME=frontend-ex \
./deploy.sh
```

Notes:

- `deploy.sh` builds the release on the server. If `mix` isn't installed on the host, it will use
  `podman` with `FX_BUILD_IMAGE` (default: `docker.io/library/elixir:1.16.3-otp-26`).

Verify:

```bash
ssh <server> "systemctl status frontend-ex --no-pager"
ssh <server> "journalctl -u frontend-ex -n 200 --no-pager"
```

## Caddy Restart (If Routing Changed)

After modifying the Caddyfile, restart Caddy:

```bash
ssh <server> "podman restart <caddy-container>"
```

## Rollback

1. Roll back the app release:

```bash
ssh <server> "cd /path/to/frontend-ex && ls -1dt releases/* | head"
ssh <server> "cd /path/to/frontend-ex && ln -sfn releases/<release_id> current && systemctl restart frontend-ex"
```

2. If you changed Caddy routing, revert the Caddyfile changes and restart Caddy.
