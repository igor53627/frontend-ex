---
id: TASK-32
title: Unify Transaction shape across controllers (parse_tx/display_tx)
status: Done
assignee: []
created_date: '2026-04-16 19:20'
updated_date: '2026-04-16 20:54'
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

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Deferred — the four `display_tx`/`parse_tx` variants are **view-specific by design**, not duplication. After close reading each site:

- `block_controller.display_tx/1`: raw wei, nested `from: %{hash: _}` / `to: %{hash: _}` (the block detail template uses nested maps).
- `txs_controller.display_tx/1`: formatted "N.NNNN ETH" string, flat `from_hash`/`to_hash`, plus `block_number`/`age`/`has_value` (list template needs age + no-value flag).
- `address_controller.display_tx/2`: takes an address perspective, adds `is_out` (downcase comparison against the viewer's address), plus `amount`/`value_eth`/`has_value` (address page needs direction indicator).
- `home_controller.display_tx/1`: adds `status`, `tx_type_label`, `tx_type_class`, `timestamp_relative`, `truncated` display variants (hero-cards).
- `tx_controller.parse_tx/1`: the full detail shape with 16 fields including gas/fee/nonce/confirmations/type/etc. — matches the detail page's data needs.

A unified `Transaction` shape would either force every page to carry all 16+ fields (bloat + wasted formatting) or add per-view transformers (same code, new layer). Neither is a net win over status-quo.

A narrower "extract just the raw JSON field accessors" helper was also considered and rejected: each `display_tx` calls the pattern 5–7 times in a row, so the extraction saves ~5 LOC per site for +1 new module — not worth the cognitive step for readers.

Golden HTML parity tests protect the byte-for-byte output for all 4 variants; no regression risk from leaving them as-is. If a future divergence forces consolidation, the golden tests will catch any drift at that time.

Addresses TASK-32
<!-- SECTION:FINAL_SUMMARY:END -->
