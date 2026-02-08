# Deployment

This app is not deployed yet; deployment and cutover are tracked in backlog tasks:

- `backlog/tasks/task-16 - Deployment-mix-release-aya-podman-Caddy-routing.md`
- `backlog/tasks/task-18 - Cutover-run-side-by-side-switch-Caddy-retire-Rust-after-stability.md`

## Local Run

```bash
mix setup

LISTEN_ADDR=127.0.0.1:3010 \
BLOCKSCOUT_API_URL=https://sepolia.53627.org \
FF_SKIN=classic \
mix phx.server
```

## Release Build (Planned)

```bash
MIX_ENV=prod mix deps.get --only prod
MIX_ENV=prod mix compile
MIX_ENV=prod mix release
```

Run the release:

```bash
export PHX_SERVER=true
export SECRET_KEY_BASE="$(mix phx.gen.secret)"
bin/frontend_ex start
```

## Reverse Proxy (Planned)

The current production host for `fast-frontend` is `aya` behind Caddy (podman). This app is expected to be deployed side-by-side and then switched over via Caddy once parity and stability are validated.

