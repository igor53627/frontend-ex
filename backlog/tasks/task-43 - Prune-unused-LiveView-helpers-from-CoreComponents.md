---
id: TASK-43
title: Prune unused LiveView helpers from CoreComponents
status: To Do
assignee: []
created_date: '2026-04-16 19:22'
labels:
  - elixir
  - cleanup
dependencies: []
references:
  - lib/frontend_ex_web/components/core_components.ex
priority: low
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Audit core_components.ex: remove or clearly mark LiveView-only helpers (phx-update stream table/1, form, row_click) that no SSR route calls
- [ ] #2 Whatever remains either has at least one caller or carries a one-line comment explaining intent
- [ ] #3 Compilation is clean with warnings-as-errors
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
core_components.ex:29-370 is the full Phoenix scaffold LiveView grab-bag. App is SSR-only — ~90% of this is dead code. Either delete or park behind a comment so readers aren't misled about what's rendered.
<!-- SECTION:NOTES:END -->
