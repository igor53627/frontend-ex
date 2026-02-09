---
id: TASK-21
title: 'Blocks list: /blocks (SSR)'
status: To Do
assignee: []
created_date: '2026-02-09 15:04'
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

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GET /blocks renders SSR
- [ ] #2 HTML snapshot matches Rust (fixtures)
<!-- AC:END -->

## Description

Implement the missing `/blocks` page (SSR) to match `fast-frontend` output and avoid broken navigation for the Classic skin.

## Implementation Notes

- Rust reference: `fast-frontend/src/handlers/blocks.rs` and templates:
- `fast-frontend/templates/classic/blocks.html`
- `fast-frontend/templates/53627/blocks.html`
- Blockscout API: `/api/v2/blocks?limit=50` and `/api/v2/stats` (coin_price/gas_price header).
- Formatting details to match Rust:
- `time_ago` formatting ("N secs/mins/hrs/days ago")
- number formatting for gas used/limit and tx count
- Testing: add fixtures + golden snapshot test for `/blocks`.
