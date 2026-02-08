# Architecture

`frontend-ex` is a Phoenix SSR application intended to replace `fast-frontend` (Rust) while keeping byte-for-byte HTML output parity per skin.

## Request Flow

```
Browser
  -> Phoenix Endpoint (Bandit)
    -> Router pipeline
      -> Controller
        -> (optional) Blockscout API client
        -> EEx templates (skin-specific root layout + content fragments)
      -> Response (HTML)
```

## Router Pipelines

- `:fast_browser`
  - Used for parity routes.
  - No session/CSRF plugs (avoid extra HTML/meta tags and cookies).
  - Sets a skin-specific root layout via `FrontendExWeb.Plugs.FastLayout`.
  - Disables view layouts (`put_layout false`) to keep HTML 1:1.
  - Trims the final trailing newline via `FrontendExWeb.Plugs.TrimTrailingNewline` to match Askama output.

- `:browser`
  - Standard Phoenix pipeline (currently used only for the default `/` page).

## Skins

Skin selection is runtime-based:

- `FF_SKIN=53627` uses `lib/frontend_ex_web/fast_layouts/s53627.html.eex`
- `FF_SKIN=classic` uses `lib/frontend_ex_web/fast_layouts/classic.html.eex`

See `FrontendExWeb.Skin` and `FrontendExWeb.FastLayouts`.

## Templates and Parity

Parity-critical rendering uses `.html.eex` (not HEEx) to minimize framework-driven formatting.

Key configuration:

- `config :phoenix_template, :trim_on_html_eex_engine, false`
  - Prevents whitespace trimming in HTML EEx templates.

## Upstream API Client

`FrontendEx.Blockscout.Client` wraps `Req` + a shared `Finch` pool:

- Base URL: `BLOCKSCOUT_API_URL`
- Timeouts: 10s (connect + receive)
- Error mapping/retry behavior follows `fast-frontend/src/api/client.rs`:
  - 404 -> `:not_found` (no retry)
  - 429/5xx/transport -> retry once after 250ms
  - invalid JSON -> retry up to 3 attempts; then treat as `:not_found`

## Cursor Pagination

Blockscout v2 uses cursor (keyset) pagination via `next_page_params`.

Helpers:

- `FrontendEx.Blockscout.Cursor`
  - Builds a `k=v&k2=v2...` query string from `next_page_params`.
  - Encodes it as a single `cursor=` value by percent-encoding the full string.

- `FrontendExWeb.CursorLinks`
  - Builds deterministic query strings, merges existing query params, and safely encodes `cursor`.

Important nuance:

- Plug/Phoenix decode query params once. If you read `cursor` from `conn.params`, it is already decoded and may contain `&`.
- When placing a cursor back into a link, encode the decoded cursor query string before embedding it in `cursor=...` (handled by `FrontendExWeb.CursorLinks.with_cursor/3`).

## Caching

Caching strategies are tracked in backlog tasks and will mirror Rust:

- Standard cache: 60s TTL
- Immutable cache: 300s TTL
- SWR: 5s fresh / 20s stale with background refresh
