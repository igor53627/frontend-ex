---
id: TASK-35
title: 'Cache/SWR: supervise background tasks + waiter timeout'
status: To Do
assignee: []
created_date: '2026-04-16 19:21'
labels:
  - elixir
  - correctness
  - cache
dependencies: []
references:
  - lib/frontend_ex/cache.ex
  - lib/frontend_ex/cache/swr.ex
  - lib/frontend_ex/application.ex
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Background fetch/refresh tasks launched under Task.Supervisor (not Task.start)
- [ ] #2 Waiters (inflight[key].waiters, refresh_waiters) are reclaimed on task exit for ALL reasons (crash, kill, timeout) via :DOWN handler
- [ ] #3 await_refresh/3 and waiter paths have bounded max-wait; stuck waiters time out cleanly instead of blocking forever
- [ ] #4 Tests cover the crash path: start a fetch that raises, assert waiters get {:error, _} and map is clean
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
cache.ex:291, swr.ex:303, swr.ex:320 use Task.start (unsupervised). If a fetch crashes in a form the DOWN handler misses, waiters leak.
<!-- SECTION:NOTES:END -->
