---
id: TASK-42
title: Strip Phoenix scaffolding links from Layouts.ex
status: Done
assignee: []
created_date: '2026-04-16 19:22'
updated_date: '2026-04-16 20:10'
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
- [x] #1 Default Phoenix 'Website', 'GitHub', 'Get Started' links removed from lib/frontend_ex_web/components/layouts.ex
- [x] #2 app layout is empty or SSR-neutral so it cannot drift into a parity route by accident
- [x] #3 Golden tests still pass (these links are not in any parity golden)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
layouts.ex:38-60 contained boilerplate Phoenix links from scaffold. Any future non-parity route would leak them; future parity work could accidentally inherit them.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Removed the default Phoenix `Layouts.app/1` component (containing the `Website`, `GitHub`, `Get Started` scaffold links). It had no callers — only self-reference in its own docstring.

**Update:** `flash_group/1` was also removed as part of TASK-43's follow-up cleanup (along with `home.html.heex` and the `PageController` family). `FrontendExWeb.Layouts` is now a minimal module that only carries `embed_templates "layouts/*"`.

Addresses TASK-42
<!-- SECTION:FINAL_SUMMARY:END -->
