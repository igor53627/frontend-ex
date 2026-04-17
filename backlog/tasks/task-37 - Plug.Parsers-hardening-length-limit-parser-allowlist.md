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

**Update (follow-up commit 1db7dde):** AC-3 test coverage was added in a second commit after the initial roborev review flagged the gap. `test/frontend_ex_web/endpoint_parsers_test.exs` POSTs to `/health` with (a) oversized urlencoded body → 413 and (b) unsupported content-type → 415, using `assert_error_sent/2` so the full endpoint `render_errors` pipeline is exercised. The "deferred" note in earlier drafts is obsolete.

Addresses TASK-37
<!-- SECTION:FINAL_SUMMARY:END -->
