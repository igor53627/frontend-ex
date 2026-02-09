---
id: TASK-20
title: 'Transactions list: /txs (SSR + cursor pagination)'
status: To Do
assignee: []
created_date: '2026-02-09 15:04'
labels:
  - pages
  - tx
  - parity
dependencies:
  - TASK-5
  - TASK-6
  - TASK-7
  - TASK-9
  - TASK-10
  - TASK-15
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GET /txs renders SSR for both skins (or FF_SKIN=classic at minimum)
- [ ] #2 Cursor pagination uses next_page_params (no fake page numbers)
- [ ] #3 Golden HTML snapshot matches Rust
<!-- AC:END -->

## Description

`fast-frontend` exposes `/txs` as an SSR transactions list with cursor-based pagination (no page numbers). `frontend-ex` should implement the same route and render templates matching Rust output.

## Implementation Notes

- Rust reference: `fast-frontend/src/handlers/txs.rs` and templates:
- `fast-frontend/templates/classic/txs.html`
- `fast-frontend/templates/53627/txs.html`
- Blockscout API: `/api/v2/transactions?items_count=<ps>` plus cursor params from `next_page_params`.
- Query params to support (match Rust):
- `ps`: page size (10/25/50/100, default 50)
- `cursor`: encoded cursor params derived from `next_page_params`
- Pull `coin_price`, `gas_price`, and `total_transactions` from `/api/v2/stats` (used in header).
- Testing: add fixtures + golden snapshot test for `/txs` for both skins (or at least `FF_SKIN=classic`).
