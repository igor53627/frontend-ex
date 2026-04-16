---
id: TASK-41
title: 'TrimTrailingNewline: verify content-type logic + per-type tests'
status: To Do
assignee: []
created_date: '2026-04-16 19:22'
labels:
  - elixir
  - parity
  - tests
dependencies: []
references:
  - lib/frontend_ex_web/plugs/trim_trailing_newline.ex
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Plug logic re-read against its intent; docstring updated so condition and comment agree
- [ ] #2 Tests cover: text/html (trims), text/csv (does not trim), image/svg+xml (does not trim), application/json (does not trim)
- [ ] #3 Parity tests still green for both HTML and CSV golden files
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
plugs/trim_trailing_newline.ex:14 — condition reads as 'skip trimming unless starts_with text/html'. The docstring/comment is about trimming HTML only, so behavior is consistent with intent once you trace both branches, but it's unclear enough to warrant an audit + tests.
<!-- SECTION:NOTES:END -->
