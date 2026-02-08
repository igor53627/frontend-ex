# frontend-ex

Phoenix SSR app intended to replace `fast-frontend` (Rust/Axum/Askama) with byte-for-byte HTML parity per skin.

This repo is intentionally "un-Phoenix-y" in parity-critical paths: we prefer plain `.html.eex` templates and minimal helpers to keep output deterministic.

## Docs

- `docs/FEATURE_FLAGS.md`
- `docs/ARCHITECTURE.md`
- `docs/DEPLOYMENT.md`
- `docs/API_ENDPOINTS.md`

## Local Development

```bash
mix setup

# 53627-like skin (default)
LISTEN_ADDR=127.0.0.1:3010 \
BLOCKSCOUT_API_URL=https://sepolia.53627.org \
FF_SKIN=53627 \
mix phx.server

# Classic-like skin
LISTEN_ADDR=127.0.0.1:3010 \
BLOCKSCOUT_API_URL=https://sepolia.53627.org \
FF_SKIN=classic \
mix phx.server
```

## Tests

```bash
mix test
```

## Backlog

Project tasks/docs live under `backlog/` and are managed with Backlog.md:

```bash
backlog overview
backlog tasks list --plain
```

