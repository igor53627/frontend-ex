---
id: doc-2
title: parity checklist
type: other
created_date: '2026-02-08 14:16'
---

# Parity Checklist (fast-frontend Rust -> frontend-ex Phoenix)

Definition: “Parity” means the Elixir/Phoenix app serves the same routes with SSR and produces byte-for-byte identical HTML for each skin given the same upstream API responses and a controlled clock.

## HTTP Surface

- All routes from `fast-frontend` exist (see `backlog/docs/doc-1 - fast-frontend-inventory.md`).
- Status codes match:
  - 200 on success pages
  - 302 redirects for `/search`
  - 404 for not-found resources (`/tx/{hash}`, `/address/{addr}`, `/block/{id}`, `/token/{addr}`)
  - 500 on template/render errors
- Content types match:
  - HTML pages: `text/html; charset=utf-8` (Phoenix default is ok, but verify)
  - `/tx/{hash}/og-image.svg`: `image/svg+xml`, with `Cache-Control: public, max-age=300`
  - `/nft-latest-mints.csv`: `text/csv; charset=utf-8` + `Content-Disposition` attachment filename
  - `/health`: plain text `OK`
  - `/stats`: JSON (optional but recommended for ops parity)
- Static assets served at `/static/**` with identical bytes to `fast-frontend/static/**`.

## Skins

- Runtime env selects skin (per decision): e.g. `FF_SKIN=classic` or `FF_SKIN=53627`.
- Templates + CSS/JS are not “translated” using helpers that change output:
  - Use plain EEx rendering for deterministic output and whitespace preservation.
  - Avoid Phoenix HTML helpers that may alter escaping/attribute rendering.

## Upstream API Behavior

- Base URL is `BLOCKSCOUT_API_URL` (trim trailing `/`).
- Cursor pagination only:
  - Never invent page numbers.
  - Always use `next_page_params` from Blockscout v2 responses.
  - UI carries cursor as a single `cursor=` query param.
  - Cursor encoding rule:
    - Build `k=v&k2=v2...` from `next_page_params` (URL-encode keys/values)
    - Percent-encode the full string when placing into `cursor=...`
    - Decode before sending to upstream.
- Page size:
  - Match Rust behavior for `ps`/`limit` handling (10/25/50/100 normalization).
  - Ensure `items_count` cannot be overridden by cursor input (same guard as Rust token-transfers).

## Caching Semantics

Implement the same 3 strategies:

- Standard cache: TTL 60s for most API calls, with request coalescing.
- Immutable cache: TTL 300s for immutable calls (tx/block by hash, logs/state/internal, etc.).
- SWR cache:
  - age < 5s: serve fresh from cache
  - 5s <= age < 20s: serve stale and refresh in background (dedup refresh per key)
  - age >= 20s: fetch fresh before responding

Expose cache diagnostics via `/stats` (optional but very useful for ops parity).

## Rendering/Formatting

- All formatting functions from `fast-frontend/src/format.rs` reproduced exactly (including rounding rules).
- Relative-time formatting depends on “now”:
  - For deterministic tests, inject a clock (or allow override via config) so HTML snapshots are stable.
- Classic-specific timestamp formats match exactly (`+UTC` vs `UTC`).
- Address checksum (EIP-55) must match Rust output exactly.

## WebSockets (Home Page)

- `ws_url` generation matches Rust:
  - Use `BLOCKSCOUT_WS_URL` if set
  - Else derive `wss://<BLOCKSCOUT_URL host>/socket/v2/websocket?vsn=2.0.0`
- Serve `/static/js/ws-zstd.js` unchanged and ensure templates reference it the same way.

## Test Harness

- No network in unit tests: API client should be pluggable/mocked with fixture JSON.
- Golden HTML snapshot tests:
  - Render each page for both skins with fixture data and fixed clock.
  - Compare to committed golden files byte-for-byte.
  - Document how to re-generate goldens.
