---
id: TASK-18
title: 'Cutover: run side-by-side, switch Caddy, retire Rust after stability'
status: In Progress
assignee: []
created_date: '2026-02-08 13:39'
updated_date: '2026-02-09 17:33'
labels:
  - cutover
  - ops
dependencies:
  - TASK-16
  - TASK-11
  - TASK-12
  - TASK-13
  - TASK-14
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phoenix app deployed side-by-side and verified
- [ ] #2 Caddy routes switched with rollback ready
- [ ] #3 Rust fast-frontend retained for rollback until stability window passes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Prepared cutover docs (docs/RUNBOOKS/cutover.md) and updated ops/caddy snippet to include GET / routing; remaining steps require deploying on aya, enabling Caddy routing, and monitoring stability window.

Deployed on aya at 127.0.0.1:5174 (no Caddy change); verified GET / and GET /exportData return 200.

Perf tuning (safe, parity routes only): removed endpoint sessions and made TrimTrailingNewline keep iodata (avoid full-body copy). On aya warm SSR p50 improved from ~0.48ms to ~0.42ms for `/`, and ~0.84ms to ~0.71ms for `/tx` (Rust still faster, but both sub-ms; cache-miss pages are dominated by upstream API latency).
<!-- SECTION:NOTES:END -->
