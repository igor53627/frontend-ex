---
id: TASK-22
title: 'Tokens list: /tokens (SSR)'
status: Done
assignee: []
created_date: '2026-02-09 15:04'
updated_date: '2026-02-09 22:26'
labels:
  - pages
  - tokens
  - parity
dependencies:
  - TASK-5
  - TASK-7
  - TASK-9
  - TASK-10
  - TASK-15
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GET /tokens renders SSR
- [x] #2 HTML snapshot matches Rust (fixtures)
<!-- AC:END -->

## Description

Implement the missing `/tokens` page (SSR) to match `fast-frontend` output and fix Classic nav links.

## Implementation Notes

- Rust reference: `fast-frontend/src/handlers/tokens.rs` and templates:
- `fast-frontend/templates/classic/tokens.html`
- `fast-frontend/templates/53627/tokens.html`
- Blockscout API: `/api/v2/tokens?limit=50` and `/api/v2/stats` (coin_price/gas_price header).
- Ensure token row formatting/parity (name/symbol/icon, links to `/token/<address>`).
- Testing: add fixtures + golden snapshot test for `/tokens`.

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented `/tokens` SSR for both skins with `GET /api/v2/tokens?limit=50` + `GET /api/v2/stats` and byte-for-byte HTML parity tests against Rust goldens.
<!-- SECTION:FINAL_SUMMARY:END -->
