---
id: TASK-30
title: >-
  Extract FrontendExWeb.Parsers (parse_u64, normalize_opt_string, @address_re as
  defguard)
status: Done
assignee: []
created_date: '2026-04-16 19:20'
updated_date: '2026-04-16 20:02'
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
- [x] #1 parse_u64/1, normalize_opt_string/1 live in FrontendExWeb.Parsers; all 6 controllers import/alias instead of re-declaring
- [x] #2 @address_re regex lifted to a shared defguard or function (one source of truth, matching /\A0x[0-9a-fA-F]{40}\z/)
- [x] #3 BlockController and any other param-accepting controllers use a single shared block-ID validator (int or 0x64-hex hash)
- [x] #4 Golden tests pass; invalid-input behavior unchanged (404)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Audit (2026-04-16): parse_u64/normalize_opt_string duplicated in address_controller.ex:340, tx_controller.ex:969, block_controller.ex:473, txs_controller.ex:393. @address_re literally redeclared 6x (tx_controller.ex:13, address_controller.ex:13, address_tabs_controller.ex:14, token_controller.ex:14, ...). Consider a defguard so match-heads can pattern-match valid addresses directly.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Extracted `FrontendExWeb.Parsers` with `parse_u64/1`, `parse_int_or/2`, `normalize_opt_string/1`, `eth_address?/1`, `tx_hash?/1`, `block_id?/1`, plus `address_regex/0` and `hash32_regex/0` accessors. Wired into the `:controller` macro alongside `ControllerHelpers`.

Consolidated 6 divergent `parse_u64` copies onto the trim-tolerant variant (was inconsistent: 4 trimmed, 2 didn't). Consolidated 3 `parse_int_or` copies onto the 4-clause general version (nil + integer + binary + fallback). Removed 4 redundant `@address_re` attributes, 1 `@tx_hash_re`, 1 `@eth_address_re`, 1 `@block_hash_re`, 1 `@block_height_re`. Replaced `defp valid_block_id?/1` in `BlockController` with the shared `block_id?/1`.

Note on defguards: Ethereum address/hash validation requires a regex match across 40–64 hex characters, which `defguard` can't express cleanly without unrolling per-byte checks. Predicate functions (`eth_address?/1` etc.) are the pragmatic choice.

Net: -116 LOC controllers, +100 LOC module, +29 unit tests. All 154 tests pass.

Addresses TASK-30
<!-- SECTION:FINAL_SUMMARY:END -->
