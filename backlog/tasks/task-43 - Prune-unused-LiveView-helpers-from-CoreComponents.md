---
id: TASK-43
title: Prune unused LiveView helpers from CoreComponents
status: Done
assignee: []
created_date: '2026-04-16 19:22'
updated_date: '2026-04-16 20:11'
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
- [x] #1 Audit core_components.ex: remove or clearly mark LiveView-only helpers (phx-update stream table/1, form, row_click) that no SSR route calls
- [x] #2 Whatever remains either has at least one caller or carries a one-line comment explaining intent
- [x] #3 Compilation is clean with warnings-as-errors
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
core_components.ex:29-370 is the full Phoenix scaffold LiveView grab-bag. App is SSR-only — ~90% of this is dead code. Either delete or park behind a comment so readers aren't misled about what's rendered.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Deleted dead Phoenix scaffold: `core_components.ex` (469 LOC) had zero callers; every component (`flash`, `button`, `input`, `header`, `table`, `list`, `icon`, `translate_error[s]`) was unreferenced. Also deleted the unused `PageController`, `PageHTML`, `page_html/home.html.heex` (which was the only caller of `Layouts.flash_group/1`) and the `Layouts.flash_group/1` helper itself. Removed `import FrontendExWeb.CoreComponents` from the `:html` macro in `frontend_ex_web.ex`.

Net: -6 files, -548 LOC. `root.html.heex` (the only used layout template) needs only `live_title` from `Phoenix.Component` which was already available; `~p` sigil comes from `Phoenix.VerifiedRoutes` which stays. All 157 tests green.

Addresses TASK-43
<!-- SECTION:FINAL_SUMMARY:END -->
