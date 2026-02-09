# Deploy Runbook (Aya)

This runbook describes the operational procedure to deploy `frontend-ex` to `aya`.

## Targets

- Host: `aya`
- App path: `/mnt/sepolia/frontend-ex`
- Service: `frontend-ex` (systemd)
- Caddy container (podman): `blockscout-proxy_caddy_1`
- Caddyfile: `/mnt/sepolia/blockscout-proxy/Caddyfile`

## Deploy

Run from your local machine:

```bash
FX_DEPLOY_SERVER=aya \
FX_DEPLOY_PATH=/mnt/sepolia/frontend-ex \
FX_SERVICE_NAME=frontend-ex \
./deploy.sh
```

Notes:

- `deploy.sh` builds the release on `aya`. If `mix` isn't installed on the host, it will use
  `podman` with `FX_BUILD_IMAGE` (default: `docker.io/library/elixir:1.16.3-otp-26`).

Verify:

```bash
ssh aya "systemctl status frontend-ex --no-pager"
ssh aya "journalctl -u frontend-ex -n 200 --no-pager"
```

## Caddy Restart (If Routing Changed)

After modifying the Caddyfile, restart Caddy:

```bash
ssh aya "podman restart blockscout-proxy_caddy_1"
```

## Rollback

1. Roll back the app release:

```bash
ssh aya "cd /mnt/sepolia/frontend-ex && ls -1dt releases/* | head"
ssh aya "cd /mnt/sepolia/frontend-ex && ln -sfn releases/<release_id> current && systemctl restart frontend-ex"
```

2. If you changed Caddy routing, revert the Caddyfile changes and restart Caddy:

```bash
ssh aya "podman restart blockscout-proxy_caddy_1"
```
