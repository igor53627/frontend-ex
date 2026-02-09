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
    - `GET /api/v2/transactions/:hash`
    - `GET /api/v2/transactions/:hash/logs`
    - `GET /api/v2/blocks?limit=1` (SWR; confirmations)
    - `GET /api/v2/addresses/:address` (from/to flags; `to` is best-effort)

- `GET /tx/:hash/internal`
- `GET /tx/:hash/logs`
- `GET /tx/:hash/state`
- `GET /tx/:hash/card`
  - Placeholder routes for tabs/links; currently `302` redirect to `GET /tx/:hash`.

- `GET /address/:address`
  - SSR HTML address page
  - Upstream calls (Blockscout API v2):
    - `GET /api/v2/stats`
    - `GET /api/v2/addresses/:address`
    - `GET /api/v2/addresses/:address/transactions` (cursor passthrough via `?cursor=` UI param)
    - `GET /api/v2/addresses/:address/tokens`

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

Encoding:

1. Build `k=v&k2=v2...` from `next_page_params` (encode each key/value).
2. Percent-encode the full string for the `cursor` value (encode `&` and `=`).

Implementation:

- `FrontendEx.Blockscout.Cursor.next_page_params_query/1`
- `FrontendEx.Blockscout.Cursor.encode_next_page_params/1`
