---
id: TASK-41
title: 'TrimTrailingNewline: verify content-type logic + per-type tests'
status: Done
assignee: []
created_date: '2026-04-16 19:22'
updated_date: '2026-04-16 20:15'
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
- [x] #1 Plug logic re-read against its intent; docstring updated so condition and comment agree
- [x] #2 Tests cover: text/html (trims), text/csv (does not trim), image/svg+xml (does not trim), application/json (does not trim)
- [x] #3 Parity tests still green for both HTML and CSV golden files
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
plugs/trim_trailing_newline.ex:14 — condition reads as 'skip trimming unless starts_with text/html'. The docstring/comment is about trimming HTML only, so behavior is consistent with intent once you trace both branches, but it's unclear enough to warrant an audit + tests.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Audited the plug: the condition is correct, not inverted as initially feared. Behavior matrix:
- `text/html[; charset=...]` → trim
- Missing content-type → trim (fallback for SSR default flow)
- Any explicit non-HTML type (CSV, SVG, JSON, plain) → pass through

Clarified the intent with an expanded inline comment. Added 6 dispatch tests covering `text/html`, `text/html; charset=utf-8`, `text/csv`, `image/svg+xml`, `application/json`, `text/plain`. 166 tests pass.

Addresses TASK-41
<!-- SECTION:FINAL_SUMMARY:END -->
