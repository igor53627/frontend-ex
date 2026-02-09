---
id: TASK-19
title: 'Routing: /search + /health + /stats'
status: Done
assignee: []
created_date: '2026-02-09 15:04'
updated_date: '2026-02-09 15:21'
labels:
  - routing
  - ops
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`frontend-ex` currently 404s for `/search`, `/health`, and `/stats`. `fast-frontend` implements these endpoints and they are useful for navigation (search form) and ops/debugging.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 /search matches fast-frontend redirect semantics
- [x] #2 /health returns 200 OK (plain text)
- [x] #3 /stats returns JSON (cache sizes + config)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Rust reference: `fast-frontend/src/handlers/search.rs` and routes in `fast-frontend/src/main.rs`.
- `/search` behavior:
- Redirect `/` when `q` is empty.
- If `q` is `0x` + 40 hex chars: redirect to `/address/<q>`.
- If `q` is `0x` + 64 hex chars: redirect to `/tx/<q>`.
- If `q` is all digits: redirect to `/block/<q>`.
- Otherwise: redirect to `<BLOCKSCOUT_URL>/search?q=<q>` (URL-encoded).
- `/health`: return `200` with body `OK` (text/plain).
- `/stats`: return JSON with cache sizes and cache config (TTL windows); keep the schema stable so it can be scraped.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Implemented /search redirect helper (address/tx/block/fallback), /health OK endpoint, and /stats JSON for cache sizes/config; added controller tests and documented routes.
<!-- SECTION:FINAL_SUMMARY:END -->
