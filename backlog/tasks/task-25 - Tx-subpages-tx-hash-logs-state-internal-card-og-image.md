---
id: TASK-25
title: 'Tx subpages: /tx/:hash/* (logs/state/internal/card/og-image)'
status: Done
assignee: []
created_date: '2026-02-09 15:05'
updated_date: '2026-02-10 05:17'
labels:
  - pages
  - tx
  - parity
dependencies:
  - TASK-5
  - TASK-7
  - TASK-9
  - TASK-10
  - TASK-15
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GET /tx/:hash/logs renders SSR (classic)
- [x] #2 GET /tx/:hash/state renders SSR (classic)
- [x] #3 GET /tx/:hash/internal renders SSR (classic)
- [x] #4 GET /tx/:hash/og-image.svg returns SVG (same as Rust)
- [x] #5 GET /tx/:hash/card renders share card (s53627)
<!-- AC:END -->

## Description

`frontend-ex` currently redirects `/tx/:hash/*` subpages back to the overview. `fast-frontend` renders real tab pages (Classic) and exposes share assets (SVG OG image and 53627 share card). Port these endpoints to close gaps without changing the main `/tx/:hash` parity.

## Implementation Notes

- Rust reference files:
- Tabs: `fast-frontend/src/handlers/tx_tabs.rs` (logs/state/internal)
- Share card: `fast-frontend/src/handlers/tx_card.rs` (53627)
- OG image: `fast-frontend/src/handlers/tx_og_image.rs` (`Cache-Control: public, max-age=300`)
- Templates:
- `fast-frontend/templates/classic/tx_logs.html`
- `fast-frontend/templates/classic/tx_state.html`
- `fast-frontend/templates/classic/tx_internal.html`
- `fast-frontend/templates/53627/tx_card.html`
- Blockscout API endpoints:
- `/api/v2/transactions/<hash>/logs`
- `/api/v2/transactions/<hash>/state-changes`
- `/api/v2/transactions/<hash>/internal-transactions`
- `/api/v2/transactions/<hash>` (OG image + card)
- `/api/v2/stats` (coin_price/gas_price header)
- Preserve Rust semantics:
- Internal tab supports `?advanced=true|false` (see `TxInternalQuery` in Rust).
- Logs/state/internal are treated as immutable in Rust (5 min cache).
- Testing: golden HTML snapshots for logs/state/internal + fixture-based SVG snapshot for OG image.

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented `/tx/:hash/logs`, `/tx/:hash/state`, and `/tx/:hash/internal` SSR tab pages for the Classic skin, plus `/tx/:hash/card` share card HTML and `/tx/:hash/og-image.svg` SVG with Rust-matching headers. Added Blockscout fixtures, Rust golden snapshots, and parity tests to keep output byte-for-byte.
<!-- SECTION:FINAL_SUMMARY:END -->
