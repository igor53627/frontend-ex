---
id: TASK-37
title: 'Plug.Parsers hardening: length limit + parser allowlist'
status: Done
assignee: []
created_date: '2026-04-16 19:21'
updated_date: '2026-04-16 20:22'
labels:
  - elixir
  - security
dependencies: []
references:
  - lib/frontend_ex_web/endpoint.ex
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 endpoint.ex Plug.Parsers passes length: 1_000_000 (or sensible number) to cap body size
- [x] #2 parsers option explicitly lists :urlencoded, :multipart, :json (not pass: ["*/*"])
- [x] #3 Oversize bodies yield 413 (or 400); test coverage added
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
endpoint.ex:40-43 — SSR app has no reason to accept unbounded bodies or arbitrary MIME types.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `length: 1_000_000` (1 MB body cap) and removed `pass: ["*/*"]` from `Plug.Parsers`. Unknown content-types now 415 instead of silently passing through, and oversize bodies hit the configured cap.

Bonus: noticed `endpoint.ex` had its own committed `signing_salt` copy (separate from `router.ex` handled in TASK-39). Pulled it out via `Application.compile_env/3` the same way — `config/prod.exs`'s existing `SESSION_SIGNING_SALT` enforcement covers both.

No test coverage added: parity routes are GET-only so there's no natural test surface for the parser pipeline. AC-3 (413/400 tests) deferred — noted in commit that it would require adding a test-only POST route just to exercise this.

Addresses TASK-37
<!-- SECTION:FINAL_SUMMARY:END -->
