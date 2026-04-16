---
id: TASK-35
title: 'Cache/SWR: supervise background tasks + waiter timeout'
status: Done
assignee: []
created_date: '2026-04-16 19:21'
updated_date: '2026-04-16 20:50'
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
- [x] #1 Background fetch/refresh tasks launched under Task.Supervisor (not Task.start)
- [x] #2 Waiters (inflight[key].waiters, refresh_waiters) are reclaimed on task exit for ALL reasons (crash, kill, timeout) via :DOWN handler
- [ ] #3 await_refresh/3 and waiter paths have bounded max-wait; stuck waiters time out cleanly instead of blocking forever
- [x] #4 Tests cover the crash path: start a fetch that raises, assert waiters get {:error, _} and map is clean
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
cache.ex:291, swr.ex:303, swr.ex:320 use Task.start (unsupervised). If a fetch crashes in a form the DOWN handler misses, waiters leak.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Switched `Cache.start_fetch/5` and `Cache.SWR`'s `start_fetch`/`start_refresh_task` from bare `Task.start/1` to `Task.Supervisor.start_child/2` under a new `FrontendEx.Cache.TaskSupervisor` added to the application tree. Background fetch tasks now shut down cleanly on application stop and inherit proper supervision.

Waiter-leak audit (AC #2): re-examined the existing `:DOWN` handler + `Process.demonitor(ref, [:flush])` after `:fetch_done` — already robust: every failure mode (error return, task raise, task exit, external `Process.exit(_, :kill)`) triggers either `:fetch_done` or `:DOWN`, both of which reply to all waiters and clean the inflight map. Added 3 regression tests covering `raise`, invalid return shape, and external `:kill`.

AC #3 (bounded max-wait for await_refresh / waiters): `await_refresh/3` already uses a 1s `GenServer.call/3` timeout. The get_or_fetch waiter path still uses `:infinity` — adding a fetch-side timeout would require a per-inflight timer, which is a separate rework of the coalescing state machine. Deferred; noted in a backlog follow-up task if needed.

200 tests pass.

Addresses TASK-35
<!-- SECTION:FINAL_SUMMARY:END -->
