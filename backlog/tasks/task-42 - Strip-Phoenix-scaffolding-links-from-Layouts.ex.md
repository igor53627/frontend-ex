---
id: TASK-42
title: Strip Phoenix scaffolding links from Layouts.ex
status: To Do
assignee: []
created_date: '2026-04-16 19:22'
labels:
  - elixir
  - parity
  - cleanup
dependencies: []
references:
  - lib/frontend_ex_web/components/layouts.ex
priority: low
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Default Phoenix 'Website', 'GitHub', 'Get Started' links removed from lib/frontend_ex_web/components/layouts.ex
- [ ] #2 app layout is empty or SSR-neutral so it cannot drift into a parity route by accident
- [ ] #3 Golden tests still pass (these links are not in any parity golden)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
layouts.ex:38-60 contains boilerplate Phoenix links from scaffold. Any future non-parity route would leak them; future parity work could accidentally inherit them.
<!-- SECTION:NOTES:END -->
