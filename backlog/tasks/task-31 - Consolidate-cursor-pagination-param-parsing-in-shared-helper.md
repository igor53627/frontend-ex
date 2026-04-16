---
id: TASK-31
title: Consolidate cursor/pagination param parsing in shared helper
status: To Do
assignee: []
created_date: '2026-04-16 19:20'
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
- [ ] #3 Golden tests cover pagination edge cases (empty next_page_params, malformed cursor, size bounds)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audit (2026-04-16): cursor parsing duplicated across txs_controller.ex:129-196, token_controller.ex, nft_controller.ex with subtle variants. Existing FrontendEx.Blockscout.Cursor module is a natural home.
<!-- SECTION:NOTES:END -->
