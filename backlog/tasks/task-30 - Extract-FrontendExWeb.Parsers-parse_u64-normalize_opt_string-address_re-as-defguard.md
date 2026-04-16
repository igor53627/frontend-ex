---
id: TASK-30
title: >-
  Extract FrontendExWeb.Parsers (parse_u64, normalize_opt_string, @address_re as
  defguard)
status: To Do
assignee: []
created_date: '2026-04-16 19:20'
labels:
  - elixir
  - refactor
dependencies: []
references:
  - lib/frontend_ex_web/controllers/address_controller.ex
  - lib/frontend_ex_web/controllers/tx_controller.ex
  - lib/frontend_ex_web/controllers/block_controller.ex
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 parse_u64/1, normalize_opt_string/1 live in FrontendExWeb.Parsers; all 6 controllers import/alias instead of re-declaring
- [ ] #2 @address_re regex lifted to a shared defguard or function (one source of truth, matching /\A0x[0-9a-fA-F]{40}\z/)
- [ ] #3 BlockController and any other param-accepting controllers use a single shared block-ID validator (int or 0x64-hex hash)
- [ ] #4 Golden tests pass; invalid-input behavior unchanged (404)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audit (2026-04-16): parse_u64/normalize_opt_string duplicated in address_controller.ex:340, tx_controller.ex:969, block_controller.ex:473, txs_controller.ex:393. @address_re literally redeclared 6x (tx_controller.ex:13, address_controller.ex:13, address_tabs_controller.ex:14, token_controller.ex:14, ...). Consider a defguard so match-heads can pattern-match valid addresses directly.
<!-- SECTION:NOTES:END -->
