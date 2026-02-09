---
id: TASK-26
title: 'NFT pages: /nft-transfers + /nft-latest-mints (+ csv)'
status: To Do
assignee: []
created_date: '2026-02-09 15:05'
labels:
  - pages
  - nft
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
- [ ] #1 GET /nft-transfers renders SSR with cursor pagination
- [ ] #2 GET /nft-latest-mints renders SSR with cursor pagination
- [ ] #3 GET /nft-latest-mints.csv exports CSV matching Rust
<!-- AC:END -->

## Description

Port the NFT endpoints from `fast-frontend` so the Classic nav item “NFT Transfers” works and the “Latest NFT mints” export is available:

- `/nft-transfers`
- `/nft-latest-mints`
- `/nft-latest-mints.csv`

## Implementation Notes

- Rust reference: `fast-frontend/src/handlers/nft_transfers.rs` and templates:
- `fast-frontend/templates/classic/nft_transfers.html`
- `fast-frontend/templates/classic/nft_latest_mints.html`
- `fast-frontend/templates/53627/nft_transfers.html`
- `fast-frontend/templates/53627/nft_latest_mints.html`
- Blockscout API (Rust uses token transfers + filtering):
- `/api/v2/token-transfers?items_count=<ps>&type=ERC-721,ERC-1155` (+ cursor params)
- `/api/v2/stats` (coin_price/gas_price header)
- Cursor pagination must use `next_page_params` (no page numbers).
- CSV export must match Rust for columns, ordering, and filtering options (see `NftMintsExportQuery` in Rust).
- Testing: golden snapshots for HTML pages and fixture-based CSV snapshot for export.
