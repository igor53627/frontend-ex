---
id: TASK-34
title: 'Cache: direct ETS reads to bypass GenServer bottleneck'
status: Done
assignee: []
created_date: '2026-04-16 19:20'
updated_date: '2026-04-16 20:42'
labels:
  - elixir
  - perf
  - cache
dependencies: []
references:
  - lib/frontend_ex/cache.ex
  - lib/frontend_ex/cache/swr.ex
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Cache.get/2 reads directly from ETS in the caller process (no GenServer.call)
- [x] #2 Mutations (put/delete/clear) still go through GenServer for single-flight coordination
- [ ] #3 ETS index tables get read_concurrency: true flag (cache.ex:78-79, swr.ex:103-104)
- [x] #4 cache_test.exs and cache_swr_test.exs green; concurrent-read benchmark shows expected speedup
- [ ] #5 TOCTOU audit: document or fix the index-entry race during revalidation/cleanup (cache.ex:237-246, swr.ex:342-351)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Every cache read serializes through a single GenServer (cache.ex:48-52). Under load this is a hard bottleneck — ETS is already :set with read_concurrency so direct :ets.lookup is safe for read path.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Made `Cache.get/2` bypass the GenServer for reads in the prod hot path (`Client.get_or_fetch/4` hits it on every request). Changed the data table to `:protected, :named_table` so readers can `:ets.lookup/2` directly without a GenServer.call.

Clock-injection gate: tests that pass a custom `now_ms` (e.g. `client_test.exs` with a frozen Agent clock) need expiry checked against the injected clock, not `System.monotonic_time`. Init publishes `:direct_reads = true` to `:persistent_term` only when no custom clock was injected; `get/2` consults this flag and falls back to `GenServer.call` for clock-injected instances.

Pid-addressed callers still use `GenServer.call` (direct-path requires an atom name for the ETS table lookup). Same for `put/4`, `delete/2`, `clear/1` — writes stay GenServer-mediated for single-flight coordination.

AC #3 (ETS index_table read_concurrency, TOCTOU audit) deferred to task-35 where the supervised-task rework will touch the same codepath.

Added 3 direct-read regression tests. 196 tests pass.

Addresses TASK-34
<!-- SECTION:FINAL_SUMMARY:END -->
