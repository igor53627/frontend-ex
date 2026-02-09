---
id: TASK-21
title: 'Blocks list: /blocks (SSR)'
status: Done
assignee: []
created_date: '2026-02-09 15:04'
updated_date: '2026-02-09 15:59'
labels:
  - pages
  - blocks
  - parity
dependencies:
  - TASK-5
  - TASK-7
  - TASK-9
  - TASK-10
  - TASK-15
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the missing `/blocks` page (SSR) to match `fast-frontend` output and avoid broken navigation for the Classic skin.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 GET /blocks renders SSR
- [x] #2 HTML snapshot matches Rust (fixtures)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Rust reference: `fast-frontend/src/handlers/blocks.rs` and templates:
- `fast-frontend/templates/classic/blocks.html`
- `fast-frontend/templates/53627/blocks.html`
- Blockscout API: `/api/v2/blocks?limit=50` and `/api/v2/stats` (coin_price/gas_price header).
- Formatting details to match Rust:
- `time_ago` formatting ("N secs/mins/hrs/days ago")
- number formatting for gas used/limit and tx count
- Testing: add fixtures + golden snapshot test for `/blocks`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added /blocks SSR (Classic + 53627), including Rust-matching time_ago formatting, fixtures + Rust goldens parity test, and docs.
<!-- SECTION:FINAL_SUMMARY:END -->
