# Deployment

Deployment and cutover are tracked in backlog tasks:

- `backlog/tasks/task-16 - Deployment-mix-release-aya-podman-Caddy-routing.md`
- `backlog/tasks/task-18 - Cutover-run-side-by-side-switch-Caddy-retire-Rust-after-stability.md`

## Target Host (Aya)

- Server: `aya` (`ssh aya`)
- App path: `/mnt/sepolia/frontend-ex`
- Service: `frontend-ex` (systemd)
- Default listen (internal): `127.0.0.1:5174`
- Caddy:
  - Caddyfile: `/mnt/sepolia/blockscout-proxy/Caddyfile`
  - Container: `blockscout-proxy_caddy_1` (podman)

## Local Run

```bash
mix setup

LISTEN_ADDR=127.0.0.1:3010 \
BLOCKSCOUT_API_URL=https://sepolia.53627.org \
FF_SKIN=classic \
mix phx.server
```

## Release Build

Build a runnable release:

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release --overwrite
```

On `aya`, if you don't have Elixir/Erlang installed on the host, you can build using `podman`
instead (recommended):

```bash
podman run --rm \
  -v /mnt/sepolia/frontend-ex:/app \
  -w /app \
  -e MIX_ENV=prod \
  -e MIX_HOME=/app/.mix \
  -e HEX_HOME=/app/.hex \
  docker.io/library/elixir:1.16.3-otp-26 \
  sh -lc 'mix local.hex --force && mix local.rebar --force && mix deps.get --only prod && mix compile && mix release --overwrite'
```

Run the release:

```bash
export PHX_SERVER=true
export SECRET_KEY_BASE="$(mix phx.gen.secret)"

# Example: bind locally for a quick smoke test
export LISTEN_ADDR=127.0.0.1:3010

_build/prod/rel/frontend_ex/bin/frontend_ex start
```

## Systemd Service (Aya)

1. Copy unit + env file:

```bash
sudo install -m 0644 /mnt/sepolia/frontend-ex/ops/systemd/frontend-ex.service /etc/systemd/system/frontend-ex.service
sudo install -m 0600 /mnt/sepolia/frontend-ex/ops/systemd/frontend-ex.env.example /mnt/sepolia/frontend-ex/frontend-ex.env
sudo $EDITOR /mnt/sepolia/frontend-ex/frontend-ex.env
```

2. Reload + enable:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now frontend-ex
sudo systemctl status frontend-ex
```

## Deploy

From your local machine:

```bash
FX_DEPLOY_SERVER=aya \
FX_DEPLOY_PATH=/mnt/sepolia/frontend-ex \
FX_SERVICE_NAME=frontend-ex \
./deploy.sh
```

Options:

- `--dry-run`
- `--skip-sync`
- `--skip-build`
- `--skip-restart`

## Caddy Routing (Aya)

Merge `ops/caddy/Caddyfile.frontend-ex.snippet` into `/mnt/sepolia/blockscout-proxy/Caddyfile`
inside the main `:80 { ... }` block, then restart Caddy:

```bash
ssh aya "podman restart blockscout-proxy_caddy_1"
```

## Rollback

1. Roll back the app release:

```bash
ssh aya "cd /mnt/sepolia/frontend-ex && ls -1dt releases/* | head"
# Pick a previous release dir and point `current` to it:
ssh aya "cd /mnt/sepolia/frontend-ex && ln -sfn releases/<release_id> current && systemctl restart frontend-ex"
```

2. If you changed Caddy routing, revert the Caddyfile changes and restart Caddy:

```bash
ssh aya "podman restart blockscout-proxy_caddy_1"
```

The current production host for `fast-frontend` is `aya` behind Caddy (podman). This app is intended to run side-by-side first and only be switched over via Caddy once parity and stability are validated.
