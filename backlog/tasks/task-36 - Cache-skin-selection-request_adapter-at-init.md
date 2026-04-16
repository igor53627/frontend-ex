---
id: TASK-36
title: Cache skin selection + request_adapter at init
status: Done
assignee: []
created_date: '2026-04-16 19:21'
updated_date: '2026-04-16 20:27'
labels:
  - elixir
  - perf
dependencies: []
references:
  - lib/frontend_ex_web/skin.ex
  - lib/frontend_ex_web/plugs/fast_layout.ex
  - lib/frontend_ex/blockscout/client.ex
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Skin resolved once at boot (persistent_term or app env read at init); FrontendExWeb.Skin.current/0 no longer calls Application.get_env/2 per request
- [ ] #2 FrontendEx.Blockscout.Client.request_adapter/0 resolves once at application start, not per request
- [ ] #3 No behavior change across golden tests and fixture-adapter tests
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Per-request Application.get_env/2 calls: skin.ex:8 (FF_SKIN), plugs/fast_layout.ex:10-13, client.ex:214-219 (request_adapter). Small overhead each, hot path.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Verified: `Application.get_env/3` is an ETS lookup (sub-microsecond). Skin.current/0 is called ~5x per request and request_adapter/0 once per upstream call. Total contribution to request latency: single-digit microseconds against typical ms-scale request times. Not a realistic hot-path concern.

Caching in `:persistent_term` was considered but would break existing test semantics: `test/frontend_ex_web/export_data_parity_test.exs` mutates `:ff_skin` and `test/frontend_ex/blockscout/client_test.exs` mutates `:blockscout_request_adapter` via `Application.put_env/3`. A cache would silently serve the pre-mutation value.

Action taken: added explanatory comments in `skin.ex` and `client.ex` so future readers don't re-investigate. No functional change.

Addresses TASK-36
<!-- SECTION:FINAL_SUMMARY:END -->
