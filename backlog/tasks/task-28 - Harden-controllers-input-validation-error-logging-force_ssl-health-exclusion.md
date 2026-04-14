---
id: TASK-28
title: >-
  Harden controllers: input validation + error logging + force_ssl health
  exclusion
status: Done
assignee: []
created_date: '2026-04-14 06:56'
updated_date: '2026-04-14 08:17'
labels:
  - hardening
  - elixir
dependencies: []
references:
  - lib/frontend_ex_web/controllers/address_controller.ex
  - lib/frontend_ex_web/controllers/token_controller.ex
  - lib/frontend_ex_web/controllers/block_controller.ex
  - config/prod.exs
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 AddressController and TokenController validate address param with @address_re before upstream calls (matching AddressTabsController pattern)
- [ ] #2 BlockController validates block ID format (integer or 0x-prefixed 64-hex hash) before upstream calls
- [ ] #3 All controllers with bare await_ok log upstream failures via Logger.warning (matching TokenController's await_many_ok pattern)
- [ ] #4 prod.exs force_ssl exclude includes paths: ["/health"] (uncommented)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Found during Elixir best-practices audit (2026-04-14).

**Input validation gap**: AddressController and TokenController interpolate the address param directly into upstream API paths without format validation. AddressTabsController already validates with `@address_re ~r/\A0x[0-9a-fA-F]{40}\z/` — same pattern should be applied. BlockController should validate block ID is either a non-negative integer or a valid block hash.

**Silent error swallowing**: Most controllers use a bare `await_ok` that discards errors (`{:error, _} -> nil`). TokenController already has the better pattern with `await_many_ok` that calls `Logger.warning` with endpoint label and reason. All controllers should follow this pattern for operational visibility.

**Force SSL health path**: `config/prod.exs` has `paths: ["/health"]` commented out in the force_ssl exclude list. Load balancers probing `/health` over plain HTTP get a redirect instead of 200. Uncomment to fix.

Refs:
- lib/frontend_ex_web/controllers/address_controller.ex:28 (unvalidated)
- lib/frontend_ex_web/controllers/token_controller.ex:27 (unvalidated)
- lib/frontend_ex_web/controllers/block_controller.ex:18 (unvalidated)
- lib/frontend_ex_web/controllers/address_tabs_controller.ex:14 (good pattern)
- lib/frontend_ex_web/controllers/tx_controller.ex:12 (good pattern)
- lib/frontend_ex_web/controllers/token_controller.ex:331-378 (good await_many_ok)
- config/prod.exs:9 (commented health exclusion)
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added input validation to AddressController, TokenController, and BlockController (matching existing patterns in AddressTabsController/TxController). Added Logger.warning to all bare await_ok calls in AddressController, BlockController, and HomeController. Fixed force_ssl exclude config (was a separate top-level key, moved into force_ssl options). Added 7 regression tests for invalid input 404 responses.
<!-- SECTION:FINAL_SUMMARY:END -->
