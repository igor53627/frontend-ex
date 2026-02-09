# API Endpoints

This document describes the HTTP surface exposed by `frontend-ex` and the upstream APIs it consumes.

## Public HTTP Routes (frontend-ex)

Parity routes (pipeline `:fast_browser`):

- `GET /`
  - SSR HTML home page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/blocks?limit=6` (SWR)
    - `GET /api/v2/transactions?items_count=6` (SWR)

- `GET /search?q=<q>`
  - Redirect helper used by the Classic search form.
  - Behavior:
    - empty `q` -> `302 /`
    - `0x` + 40 hex -> `302 /address/<q>`
    - `0x` + 64 hex -> `302 /tx/<q>`
    - all digits -> `302 /block/<q>`
    - otherwise -> `302 <BLOCKSCOUT_URL>/search?q=<q>`

- `GET /blocks`
  - SSR HTML blocks list page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/blocks?limit=50`

- `GET /txs`
  - SSR HTML transactions list page
  - Supports cursor-based pagination via the `cursor=` UI param (see "Cursor Pagination" section below).
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/transactions?items_count=<ps>` (plus cursor params from `next_page_params`)

- `GET /tokens`
  - SSR HTML tokens list page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/tokens?limit=50`

- `GET /nft-transfers`
  - SSR HTML NFT transfers page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/token-transfers?items_count=<ps>&type=ERC-721,ERC-1155` (cursor-based pagination)

- `GET /nft-latest-mints`
  - SSR HTML NFT latest mints page (filters mint events from token transfers)
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/token-transfers?items_count=<ps>&type=ERC-721,ERC-1155` (cursor-based pagination)

- `GET /nft-latest-mints.csv`
  - CSV export (attachment `nft-latest-mints.csv`)
  - Query params (parity with Rust):
    - `mode=date` with `start_date=YYYY-MM-DD` and `end_date=YYYY-MM-DD` (default)
    - `mode=block` with `start_block=<u64>` and `end_block=<u64>`
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/token-transfers?items_count=<ps>&type=ERC-721,ERC-1155` (paged up to 50 requests, up to 1000 rows)

- `GET /token/:address`
  - SSR HTML token page (overview + transfers)
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/tokens/:address`
    - `GET /api/v2/tokens/:address/transfers` (cursor passthrough via `?cursor=` UI param)

- `GET /token/:address/holders`
  - SSR HTML token holders page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/tokens/:address`
    - `GET /api/v2/tokens/:address/holders` (cursor passthrough via `?cursor=` UI param)

- `GET /block/:id`
  - SSR HTML block details page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/blocks/:id`
    - `GET /api/v2/blocks/:id/transactions` (preview)
    - `GET /api/v2/blocks/:height-1` (fee recipient delta; best-effort)

- `GET /block/:id/txs`
  - SSR HTML block transactions page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/blocks/:id`
    - `GET /api/v2/blocks/:id/transactions`

- `GET /tx/:hash`
  - SSR HTML transaction details page
  - Input validation:
    - Invalid hashes (not `0x` + 64 hex chars) return `404 Transaction not found` without upstream calls.
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/transactions/:hash` (cached 300s)
    - `GET /api/v2/transactions/:hash/logs` (cached 300s)
    - `GET /api/v2/blocks?limit=1` (SWR; confirmations)
    - `GET /api/v2/addresses/:address` (from/to flags; `to` is best-effort)

- `GET /tx/:hash/logs` (classic skin)
  - SSR HTML transaction "Logs" tab page
  - Input validation:
    - Invalid hashes (not `0x` + 64 hex chars) return `404 Transaction not found` without upstream calls.
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/transactions/:hash/logs` (cached 300s)

- `GET /tx/:hash/state` (classic skin)
  - SSR HTML transaction "State" tab page
  - Input validation:
    - Invalid hashes (not `0x` + 64 hex chars) return `404 Transaction not found` without upstream calls.
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/transactions/:hash/state-changes` (cached 300s)
    - `GET /api/v2/transactions/:hash/logs` (cached 300s; tab count)

- `GET /tx/:hash/internal` (classic skin)
  - SSR HTML transaction "Internal Txns" tab page
  - Query params:
    - `advanced=true|false` toggles showing zero value internal transactions (no upstream change).
  - Input validation:
    - Invalid hashes (not `0x` + 64 hex chars) return `404 Transaction not found` without upstream calls.
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/transactions/:hash/internal-transactions` (cached 300s)
    - `GET /api/v2/transactions/:hash/logs` (cached 300s; tab count)

- `GET /tx/:hash/card`
  - Standalone share card HTML (s53627 style; not wrapped in skin root layout)
  - Input validation:
    - Invalid hashes (not `0x` + 64 hex chars) return `404 Transaction not found` without upstream calls.
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/transactions/:hash` (cached 300s)

- `GET /tx/:hash/og-image.svg`
  - SVG OG image (`Content-Type: image/svg+xml`, `Cache-Control: public, max-age=300`)
  - Input validation:
    - Invalid hashes (not `0x` + 64 hex chars) return `404 Transaction not found` without upstream calls.
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/transactions/:hash` (cached 300s)

- `GET /address/:address`
  - SSR HTML address page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/addresses/:address`
    - `GET /api/v2/addresses/:address/transactions` (cursor passthrough via `?cursor=` UI param)
    - `GET /api/v2/addresses/:address/tokens`

- `GET /address/:address/tokens` (classic skin)
  - SSR HTML address "Token Holdings" tab page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/addresses/:address`
    - `GET /api/v2/addresses/:address/tokens`

- `GET /address/:address/token-transfers` (classic skin)
  - SSR HTML address "Token Transfers" tab page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/addresses/:address`
    - `GET /api/v2/addresses/:address/token-transfers`
    - `GET /api/v2/addresses/:address/tokens` (header token holdings count)

- `GET /address/:address/internal` (classic skin)
  - SSR HTML address "Internal Transactions" tab page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/addresses/:address`
    - `GET /api/v2/addresses/:address/internal-transactions`
    - `GET /api/v2/addresses/:address/tokens` (header token holdings count)

- `GET /exportData`
  - SSR HTML page (no upstream calls)

Static assets (served by `Plug.Static`, not the router):

- `GET /static/**`
  - Parity CSS/JS copied from `fast-frontend/static/**` (served from `priv/static/static/**`)

Non-parity routes (pipeline `:browser`):

- (none yet)

Ops/debug routes (no router pipeline):

- `GET /health`
  - `200 OK` with body `OK` (text/plain).

- `GET /stats`
  - `200 OK` JSON with cache sizes/config (used for debugging and scraping).

Monitoring UI routes (local-only):

- `GET /_dashboard` (and `/_dashboard/*` assets/pages)
  - Phoenix LiveDashboard for ad-hoc BEAM/Phoenix inspection.
  - Intended access: SSH port-forward to the Phoenix listener on `aya` (see `docs/DEPLOYMENT.md`).
  - Requests that appear to come from a reverse proxy (`X-Forwarded-*`/`Forwarded`) return `404`.

The intended full route list is the same as `fast-frontend` (see `backlog/docs/doc-1 - fast-frontend-inventory.md`).

## Upstream HTTP (Blockscout API v2)

Base URL:

- `BLOCKSCOUT_API_URL` is used as the upstream base.
- Paths are under `/api/v2/...`.

Client behavior (current implementation in `FrontendEx.Blockscout.Client`):

- Sends `Accept: application/json`
- Timeouts: 10s (connect and receive)
- Error mapping:
  - 404 -> `{:error, :not_found}`
  - 429/5xx -> one retry after 250ms, then `{:error, {:http_status, status, body}}`
  - transport errors -> one retry after 250ms, then `{:error, {:transport, reason}}`
  - invalid JSON in a 2xx response -> retry up to 3 attempts total, then `{:error, :not_found}`

## Cursor Pagination (Blockscout)

Blockscout v2 pagination is cursor-based and uses `next_page_params` from responses.

Rule:

- Never invent page numbers.
- Always send back the `next_page_params` values as query params on the next request.

UI transport:

- The UI carries cursor state as a single `cursor=` query parameter.
- `cursor` value is a *percent-encoded* query string, so it can be embedded safely without breaking query parsing.

Exception (parity with Rust):

- Token pages currently render `next_page_params` as a raw query string (not percent-encoded) inside the `cursor=` href.
  - Example: `cursor=index=50&amp;items_count=50`
  - This means the browser treats `items_count` as a separate query param.
  - The server reads `cursor` and passes it through as a partial query string (e.g. `index=50`), matching the Rust behavior.

Encoding:

1. Build `k=v&k2=v2...` from `next_page_params` (encode each key/value).
2. Percent-encode the full string for the `cursor` value (encode `&` and `=`).

Implementation:

- `FrontendEx.Blockscout.Cursor.next_page_params_query/1`
- `FrontendEx.Blockscout.Cursor.encode_next_page_params/1`
