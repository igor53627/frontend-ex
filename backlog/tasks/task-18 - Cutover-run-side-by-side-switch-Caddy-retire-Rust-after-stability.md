---
id: TASK-18
title: 'Cutover: run side-by-side, switch Caddy, retire Rust after stability'
status: Done
assignee: []
created_date: '2026-02-08 13:39'
updated_date: '2026-02-10 05:52'
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
- [x] #2 Caddy routes switched with rollback ready
- [x] #3 Rust fast-frontend retained for rollback until stability window passes
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Prepared cutover docs (docs/RUNBOOKS/cutover.md) and updated the Caddy snippet; deployed `frontend-ex` to aya and switched Caddy routing to proxy the fast routes to `frontend-ex` while retaining Rust `fast-frontend` as the fallback/rollback backend.

- `frontend-ex` runs on aya at `127.0.0.1:5174` (systemd service `frontend-ex`).
- Caddy proxies the main SSR routes to `frontend-ex` and sets `X-Frontend: frontend-ex` for verification.
- Caddy preserves the incoming `X-Forwarded-Proto` header to avoid HTTPS redirect loops with `force_ssl`.
- Rust `fast-frontend` service is still running on `127.0.0.1:3002` for rollback.

Perf tuning (safe, parity routes only): removed endpoint sessions and made TrimTrailingNewline keep iodata (avoid full-body copy). On aya warm SSR p50 improved from ~0.48ms to ~0.42ms for `/`, and ~0.84ms to ~0.71ms for `/tx` (Rust still faster, but both sub-ms; cache-miss pages are dominated by upstream API latency).
<!-- SECTION:NOTES:END -->
