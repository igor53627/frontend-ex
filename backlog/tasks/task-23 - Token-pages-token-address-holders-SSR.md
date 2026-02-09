---
id: TASK-23
title: 'Token pages: /token/:address (+ /holders) (SSR)'
status: Done
assignee: []
created_date: '2026-02-09 15:04'
updated_date: '2026-02-09 23:33'
labels:
  - pages
  - token
  - parity
dependencies:
  - TASK-5
  - TASK-6
  - TASK-7
  - TASK-9
  - TASK-10
  - TASK-15
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GET /token/:address renders SSR (overview + transfers)
- [x] #2 GET /token/:address/holders renders SSR
- [x] #3 Cursor pagination uses next_page_params
<!-- AC:END -->

## Description

Port the token detail pages from `fast-frontend` so token links work end-to-end:

- `/token/:address` (overview + transfers table)
- `/token/:address/holders` (holders table)

## Implementation Notes

- Rust reference: `fast-frontend/src/handlers/token.rs` and templates:
- `fast-frontend/templates/classic/token.html`
- `fast-frontend/templates/classic/token_holders.html`
- `fast-frontend/templates/53627/token.html`
- `fast-frontend/templates/53627/token_holders.html`
- Blockscout API endpoints:
- `/api/v2/tokens/<address>`
- `/api/v2/tokens/<address>/transfers` (cursor via `next_page_params`)
- `/api/v2/tokens/<address>/holders` (cursor via `next_page_params`)
- `/api/v2/stats` (coin_price/gas_price header)
- Ensure cursor handling is keyset-based (`next_page_params`) and never fake page numbers.
- Testing: add fixtures + golden snapshots for both routes.

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented `/token/:address` and `/token/:address/holders` SSR pages for both skins, added fixtures + Rust golden HTML snapshots, and added byte-for-byte parity tests (including Rust's raw `next_page_params` cursor rendering quirk).
<!-- SECTION:FINAL_SUMMARY:END -->
