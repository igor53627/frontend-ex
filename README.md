# frontend-ex

Phoenix SSR app intended to replace `fast-frontend` (Rust/Axum/Askama) with byte-for-byte HTML parity per skin.

This repo is intentionally "un-Phoenix-y" in parity-critical paths: we prefer plain `.html.eex` templates and minimal helpers to keep output deterministic.

## Docs

- `docs/ARCHITECTURE.md` - Request flow, skins, templates, caching
- `docs/API_ENDPOINTS.md` - Full HTTP surface and upstream API usage
- `docs/FEATURE_FLAGS.md` - Environment variables and runtime config
- `docs/DEPLOYMENT.md` - Release builds, systemd, Caddy, deploy script
- `docs/RUNBOOKS/` - Operational runbooks (deploy, cutover, rollback)
- `docs/ADR/` - Architecture decision records

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

If `/txs` pagination arrows are disabled because your upstream `/api/v2/transactions` response has
`next_page_params: null`, you can override the `/txs` upstream only:

```bash
BLOCKSCOUT_TXS_API_URL=https://eth-sepolia.blockscout.com mix phx.server
```

## Tests

```bash
mix test
```

### Golden HTML Snapshots

Golden files live under `test/golden/` and represent the expected Rust `fast-frontend` HTML output.

Update (overwrite) golden files from the current Phoenix output:

```bash
UPDATE_GOLDENS=1 mix test test/frontend_ex_web/export_data_parity_test.exs
```

## Project Backlog

Development history and task tracking live under `backlog/`. See `backlog/docs/` for the original feature inventory and parity checklist, and `backlog/tasks/` for per-feature implementation records.
