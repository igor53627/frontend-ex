---
id: TASK-44
title: 'Remove empty :browser pipeline from router'
status: To Do
assignee: []
created_date: '2026-04-16 19:22'
labels:
  - elixir
  - cleanup
dependencies: []
references:
  - lib/frontend_ex_web/router.ex
priority: low
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Empty/unused :browser pipeline + scope at router.ex:129-130 removed
- [ ] #2 mix compile --warnings-as-errors and mix test stay green
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
router.ex:129-130 — leftover scaffold scope with no routes. Dead code.
<!-- SECTION:NOTES:END -->
