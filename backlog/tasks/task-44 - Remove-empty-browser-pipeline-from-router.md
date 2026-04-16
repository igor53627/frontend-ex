---
id: TASK-44
title: 'Remove empty :browser pipeline from router'
status: Done
assignee: []
created_date: '2026-04-16 19:22'
updated_date: '2026-04-16 20:08'
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
- [x] #1 Empty/unused :browser pipeline + scope at router.ex:129-130 removed
- [x] #2 mix compile --warnings-as-errors and mix test stay green
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
router.ex:129-130 — leftover scaffold scope with no routes. Dead code.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Dropped the empty `scope "/", FrontendExWeb do pipe_through :browser end` block and its adjacent commented `:api` example from `router.ex`. The `:browser` pipeline itself is still used by the `live_dashboard` scope, so it was not removed. Addresses TASK-44
<!-- SECTION:FINAL_SUMMARY:END -->
