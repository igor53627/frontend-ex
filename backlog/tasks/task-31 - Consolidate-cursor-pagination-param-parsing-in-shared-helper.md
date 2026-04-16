---
id: TASK-31
title: Consolidate cursor/pagination param parsing in shared helper
status: Done
assignee: []
created_date: '2026-04-16 19:20'
updated_date: '2026-04-16 20:31'
labels:
  - elixir
  - refactor
dependencies: []
references:
  - lib/frontend_ex_web/controllers/txs_controller.ex
  - lib/frontend_ex_web/controllers/token_controller.ex
  - lib/frontend_ex_web/controllers/nft_controller.ex
  - lib/frontend_ex/blockscout/cursor.ex
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 normalize_page_size, cursor_query_from_params, merge_cursor_params live in one module (FrontendExWeb.Pagination or FrontendEx.Blockscout.Cursor)
- [ ] #2 txs_controller, token_controller, nft_controller all call the shared helpers (no local copies)
- [x] #3 Golden tests cover pagination edge cases (empty next_page_params, malformed cursor, size bounds)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audit (2026-04-16): cursor parsing duplicated across txs_controller.ex:129-196, token_controller.ex, nft_controller.ex with subtle variants. Existing FrontendEx.Blockscout.Cursor module is a natural home.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extracted `FrontendExWeb.Pagination` with `normalize_page_size/3` and `normalize_cursor_param/1`. Wired into the `:controller` macro.

Migrated `nft_controller` (2 normalize_page_size variants + normalize_cursor_param callers) and `txs_controller` (normalize_page_size). The two controllers now delegate to the shared helper with their own `@page_size_options`/defaults.

Scope narrowed from initial AC: `txs_controller.cursor_query_from_params` / `merge_cursor_params` / `normalize_numeric_param` (txs-specific block_number+index cursor merge semantics), `token_controller.cursor_query_param` / `sanitize_cursor_query` (cap and safe-subset rebuild), and cursor reading logic stay controller-local — each upstream endpoint expects a different cursor shape, and the per-controller logic isn't duplication.

Added 13 unit tests for the shared helpers. All 181 tests pass.

Addresses TASK-31
<!-- SECTION:FINAL_SUMMARY:END -->
