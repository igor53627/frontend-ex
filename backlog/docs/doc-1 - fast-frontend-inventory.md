---
id: doc-1
title: fast-frontend inventory
type: other
created_date: '2026-02-08 14:16'
---

# fast-frontend Inventory (Rust Source Of Truth)

This document inventories the current `fast-frontend` (Rust) behavior so we can migrate it to `frontend-ex` (Elixir/Phoenix) with SSR and byte-for-byte HTML parity.

## Stack

- Rust + Axum (`src/main.rs`)
- Askama templates (`templates/**`)
- Static CSS/JS in `static/**`
- Blockscout API client with in-memory caching (Reqwest + Moka) in `src/api/client.rs`

## Skins (Current)

- Compile-time feature flags:
  - `skin-53627` (default)
  - `skin-classic`
- Templates:
  - `templates/53627/`
  - `templates/classic/`

Migration target: runtime skin selection via env (per decision: env-based).

## Routes (SSR Unless Noted)

Defined in `src/main.rs`.

| Method | Path | Handler | Template(s) | Notes |
|---|---|---|---|---|
| GET | `/` | `src/handlers/home.rs` | `53627/home.html` or `classic/home.html` | Uses SWR for blocks/txs, includes WebSocket client code in templates |
| GET | `/search` | `src/handlers/search.rs` | n/a | Redirect-only; falls back to classic explorer search if not tx/block/address |
| GET | `/txs` | `src/handlers/txs.rs` | `53627/txs.html` or `classic/txs.html` | Cursor pagination, page-size selector (`ps`/`limit`) |
| GET | `/tx/{hash}` | `src/handlers/tx.rs` | `53627/tx.html` or `classic/tx.html` | Also fetches logs count + confirmations + from/to address info |
| GET | `/tx/{hash}/card` | `src/handlers/tx_card.rs` | `53627/tx_card.html` (always) | Used for “card” rendering (even under classic skin) |
| GET | `/tx/{hash}/og-image.svg` | `src/handlers/tx_og_image.rs` | n/a | Returns SVG (`Content-Type: image/svg+xml`), `Cache-Control: public, max-age=300` |
| GET | `/tx/{hash}/logs` | `src/handlers/tx_tabs.rs` | `classic/tx_logs.html` (always) | Classic-style tab page |
| GET | `/tx/{hash}/state` | `src/handlers/tx_tabs.rs` | `classic/tx_state.html` (always) | Classic-style tab page |
| GET | `/tx/{hash}/internal` | `src/handlers/tx_tabs.rs` | `classic/tx_internal.html` (always) | Query: `advanced=true` toggles zero-value internals |
| GET | `/address/{address}` | `src/handlers/address.rs` | `53627/address.html` or `classic/address.html` | Renders 25 latest txs + 10 token balances |
| GET | `/address/{address}/token-transfers` | `src/handlers/address_tabs.rs` | `classic/address_token_transfers.html` (always) | Renders 25 transfers |
| GET | `/address/{address}/tokens` | `src/handlers/address_tabs.rs` | `classic/address_tokens.html` (always) | Renders all balances (no pagination) |
| GET | `/address/{address}/internal` | `src/handlers/address_tabs.rs` | `classic/address_internal.html` (always) | Renders 25 internals (sorted) |
| GET | `/blocks` | `src/handlers/blocks.rs` | `53627/blocks.html` or `classic/blocks.html` | Renders last 50 blocks |
| GET | `/block/{id}` | `src/handlers/block.rs` | `53627/block.html` or `classic/block.html` | Pulls block + tx list; optional RPC augmentation via `EVM_RPC_URL` |
| GET | `/block/{id}/txs` | `src/handlers/block.rs` | `53627/block_txs.html` or `classic/block_txs.html` | Uses same block tx list call as `/block/{id}` |
| GET | `/token/{address}` | `src/handlers/token.rs` | `53627/token.html` or `classic/token.html` | Cursor pagination over transfers |
| GET | `/token/{address}/holders` | `src/handlers/token.rs` | `53627/token_holders.html` or `classic/token_holders.html` | Cursor pagination over holders |
| GET | `/tokens` | `src/handlers/tokens.rs` | `53627/tokens.html` or `classic/tokens.html` | Renders 50 tokens |
| GET | `/nft-transfers` | `src/handlers/nft_transfers.rs` | `53627/nft_transfers.html` or `classic/nft_transfers.html` | Cursor pagination, page-size selector |
| GET | `/nft-latest-mints` | `src/handlers/nft_transfers.rs` | `53627/nft_latest_mints.html` or `classic/nft_latest_mints.html` | Cursor pagination, page-size selector |
| GET | `/nft-latest-mints.csv` | `src/handlers/nft_transfers.rs` | n/a | CSV export (iterates pages, max 1000 rows / 50 pages) |
| GET | `/exportData` | `src/handlers/export_data.rs` | `53627/export_data.html` or `classic/export_data.html` | No upstream calls; date/block filter UI only |
| GET | `/health` | inline | n/a | Plain text `OK` |
| GET | `/stats` | `src/main.rs` | n/a | JSON cache statistics + cache config |
| GET | `/static/*` | `ServeDir::new(\"static\")` | n/a | Static CSS/JS |

## Environment Variables

Observed via `std::env::var(...)` in code:

| Variable | Used in | Default | Purpose |
|---|---|---|---|
| `LISTEN_ADDR` | `src/main.rs` | `0.0.0.0:3000` | Bind address |
| `BLOCKSCOUT_API_URL` | `src/main.rs`, `src/handlers/home.rs` | `https://sepolia.53627.org` (main) / `https://eth-sepolia.blockscout.com` (home-only) | Upstream API base |
| `BLOCKSCOUT_URL` | most templates | `https://sepolia.53627.org` | Links to “classic explorer” pages and some API links |
| `BLOCKSCOUT_WS_URL` | `src/handlers/home.rs` | derived from `BLOCKSCOUT_URL` | WebSocket endpoint for live updates |
| `BASE_URL` | `src/handlers/tx.rs` | `https://fast.53627.org` | Used in tx page template |
| `EVM_RPC_URL` | `src/handlers/block.rs` | none; for `skin-classic` defaults to `https://ethereum-sepolia.publicnode.com` | JSON-RPC augmentation (size, extraData, withdrawals, receipts fee sum) |

## Blockscout API Endpoints Used

All calls are via `BlockscoutClient` (`src/api/client.rs`).

Caching strategies:

- Standard cache: 60s TTL (`get_cached`)
- Immutable cache: 300s TTL (`get_immutable`)
- SWR cache: 5s fresh / 20s stale (`get_swr`)

Endpoints:

- `/api/v2/stats` (standard)
- `/api/v2/blocks?limit=N` (standard), and SWR variant for home “latest blocks”
- `/api/v2/blocks/{id}` (immutable)
- `/api/v2/blocks/{id}/transactions` (immutable)
- `/api/v2/blocks/{id}/internal-transactions` (standard; used for classic-only internal tx count logic)
- `/api/v2/transactions` (standard for `/txs`, SWR for home “latest txs`)
- `/api/v2/transactions/{hash}` (immutable)
- `/api/v2/transactions/{hash}/logs` (immutable)
- `/api/v2/transactions/{hash}/state-changes` (immutable)
- `/api/v2/transactions/{hash}/internal-transactions` (immutable)
- `/api/v2/addresses/{address}` (standard)
- `/api/v2/addresses/{address}/transactions` (standard)
- `/api/v2/addresses/{address}/token-transfers` (standard)
- `/api/v2/addresses/{address}/internal-transactions` (standard)
- `/api/v2/addresses/{address}/tokens` (standard)
- `/api/v2/tokens?limit=N` (standard)
- `/api/v2/tokens/{address}` (standard)
- `/api/v2/tokens/{address}/transfers` (standard; cursor params appended)
- `/api/v2/tokens/{address}/holders` (standard; cursor params appended)
- `/api/v2/token-transfers` (standard; cursor params appended; uses `type=` filter for NFT pages)

## Pagination (Cursor / next_page_params)

Blockscout v2 uses keyset/cursor pagination: responses include `next_page_params` (object) that must be sent back as query params on the next request.

Example (from `https://eth-sepolia.blockscout.com/api/v2/transactions`):

```json
{
  "next_page_params": {
    "items_count": 50,
    "block_number": 10217968,
    "index": 82
  }
}
```

UI pattern in Rust:

- Response `next_page_params` is converted to a query string (`k=v&k2=v2...`).
- The resulting string is carried in the UI as a single `cursor=` query param.

Important for migration: the query string must be percent-encoded when placed into `cursor=...` (to avoid breaking on `&`), then decoded before calling the upstream API.

Note: `src/handlers/nft_transfers.rs` already encodes the full cursor value (correct). `src/handlers/txs.rs` and `src/handlers/token.rs` build a raw `k=v&...` cursor without encoding the full string (this will lose params when `next_page_params` has multiple keys).

## Static Assets

`static/`:

- `static/css/style1.css`, `static/css/style2.css`, `static/css/style2-overrides.css`
- `static/js/ws-zstd.js` (compressed WebSocket helper; used by classic home template)

## Formatting/Filters To Port (Byte-For-Byte)

Most formatting lives in `src/format.rs` and is used both in handlers and Askama filters.

Functions that must match exactly:

- `format_wei_to_eth`, `format_wei_to_eth_exact`
- `format_method_name`
- `format_number_with_commas`, `format_decimal_with_commas`, `format_price_with_commas`
- `unit_to_decimal_value`
- `format_relative_time`
- `format_readable_date`, `format_readable_date_classic`, `format_readable_date_classic_plus_utc`
- `checksum_eth_address` (EIP-55)
- `truncate_hash`, `truncate_addr`, `truncate_addr_classic`
