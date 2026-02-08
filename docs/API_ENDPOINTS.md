# API Endpoints

This document describes the HTTP surface exposed by `frontend-ex` and the upstream APIs it consumes.

## Public HTTP Routes (frontend-ex)

Parity routes (pipeline `:fast_browser`):

- `GET /exportData`
  - SSR HTML page (no upstream calls)

Static assets (served by `Plug.Static`, not the router):

- `GET /static/**`
  - Parity CSS/JS copied from `fast-frontend/static/**` (served from `priv/static/static/**`)

Non-parity routes (pipeline `:browser`):

- `GET /`
  - Placeholder Phoenix page (will be replaced by migrated home page)

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
