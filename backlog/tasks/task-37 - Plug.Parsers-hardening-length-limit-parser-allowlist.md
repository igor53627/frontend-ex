---
id: TASK-37
title: 'Plug.Parsers hardening: length limit + parser allowlist'
status: To Do
assignee: []
created_date: '2026-04-16 19:21'
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
- [ ] #1 endpoint.ex Plug.Parsers passes length: 1_000_000 (or sensible number) to cap body size
- [ ] #2 parsers option explicitly lists :urlencoded, :multipart, :json (not pass: ["*/*"])
- [ ] #3 Oversize bodies yield 413 (or 400); test coverage added
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
endpoint.ex:40-43 — SSR app has no reason to accept unbounded bodies or arbitrary MIME types.
<!-- SECTION:NOTES:END -->
