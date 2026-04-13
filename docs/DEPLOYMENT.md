# Deployment

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

If you don't have Elixir/Erlang installed on the host, you can build using `podman` (or Docker):

```bash
podman run --rm \
  -v /path/to/frontend-ex:/app \
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

## Systemd Service

1. Copy unit + env file:

```bash
sudo install -m 0644 ops/systemd/frontend-ex.service /etc/systemd/system/frontend-ex.service
sudo install -m 0600 ops/systemd/frontend-ex.env.example /path/to/frontend-ex.env
sudo $EDITOR /path/to/frontend-ex.env
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
FX_DEPLOY_SERVER=<server> \
FX_DEPLOY_PATH=/path/to/frontend-ex \
FX_SERVICE_NAME=frontend-ex \
./deploy.sh
```

Options:

- `--dry-run`
- `--skip-sync`
- `--skip-build`
- `--skip-restart`

## Caddy Routing

Merge `ops/caddy/Caddyfile.frontend-ex.snippet` into your Caddyfile inside the main site block, then restart Caddy:

```bash
podman restart <caddy-container>
```

## Monitoring

`frontend-ex` exposes Prometheus metrics (via `:telemetry`) on:

- `http://127.0.0.1:9568/metrics` (configurable with `FF_METRICS_ENABLED` and `FF_METRICS_PORT`)

### LiveDashboard

`frontend-ex` mounts Phoenix LiveDashboard at `/_dashboard`.

It is intentionally reachable only via direct access to the Phoenix listener (no `X-Forwarded-*` headers),
so it is not exposed through the public reverse proxy.

Access via SSH port forward:

```bash
ssh -L 4000:127.0.0.1:5174 <server>
open http://localhost:4000/_dashboard
```

## Rollback

1. Roll back the app release:

```bash
ssh <server> "cd /path/to/frontend-ex && ls -1dt releases/* | head"
# Pick a previous release dir and point `current` to it:
ssh <server> "cd /path/to/frontend-ex && ln -sfn releases/<release_id> current && systemctl restart frontend-ex"
```

2. If you changed Caddy routing, revert the Caddyfile changes and restart Caddy.
