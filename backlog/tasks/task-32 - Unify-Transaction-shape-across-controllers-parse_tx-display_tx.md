---
id: TASK-32
title: Unify Transaction shape across controllers (parse_tx/display_tx)
status: To Do
assignee: []
created_date: '2026-04-16 19:20'
labels:
  - elixir
  - refactor
dependencies: []
references:
  - lib/frontend_ex_web/controllers/tx_controller.ex
  - lib/frontend_ex_web/controllers/address_controller.ex
  - lib/frontend_ex_web/controllers/txs_controller.ex
  - lib/frontend_ex_web/controllers/block_controller.ex
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Single module (FrontendEx.Transaction or similar) exposes parse_tx/1 and display_tx/1 with documented fields
- [ ] #2 tx_controller.ex, address_controller.ex, txs_controller.ex, block_controller.ex call the shared functions; no local reshaping
- [ ] #3 Golden HTML parity unchanged; parity test suite still green
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
parse_tx at tx_controller.ex:927 and display_tx at address_controller.ex:218, txs_controller.ex:340, block_controller.ex:331 diverge in small ways. Consolidating is risk (touches rendering) — lean on golden tests.
<!-- SECTION:NOTES:END -->
