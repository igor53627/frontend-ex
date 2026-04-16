---
id: TASK-36
title: Cache skin selection + request_adapter at init
status: To Do
assignee: []
created_date: '2026-04-16 19:21'
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
