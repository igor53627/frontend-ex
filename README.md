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

### Golden HTML Snapshots

Golden files live under `test/golden/` and represent the expected Rust `fast-frontend` HTML output.

Update (overwrite) golden files from the current Phoenix output:

```bash
UPDATE_GOLDENS=1 mix test test/frontend_ex_web/export_data_parity_test.exs
```

Regenerate Rust goldens (example for `/exportData`):

```bash
# in ../fast-frontend
LISTEN_ADDR=127.0.0.1:4010 BLOCKSCOUT_API_URL=https://sepolia.53627.org \\
  cargo run --no-default-features --features skin-classic

curl -sS "http://127.0.0.1:4010/exportData?type=nft-mints&mode=date&start_date=2026-01-01&end_date=2026-02-01&start_block=123&end_block=456" \\
  > ../frontend-ex/test/golden/exportData.classic.rust.html
```

## Backlog

Project tasks/docs live under `backlog/` and are managed with Backlog.md:

```bash
backlog overview
backlog tasks list --plain
```
