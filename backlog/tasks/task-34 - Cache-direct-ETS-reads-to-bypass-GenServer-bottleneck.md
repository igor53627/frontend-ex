---
id: TASK-34
title: 'Cache: direct ETS reads to bypass GenServer bottleneck'
status: To Do
assignee: []
created_date: '2026-04-16 19:20'
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
- [ ] #1 Cache.get/2 reads directly from ETS in the caller process (no GenServer.call)
- [ ] #2 Mutations (put/delete/clear) still go through GenServer for single-flight coordination
- [ ] #3 ETS index tables get read_concurrency: true flag (cache.ex:78-79, swr.ex:103-104)
- [ ] #4 cache_test.exs and cache_swr_test.exs green; concurrent-read benchmark shows expected speedup
- [ ] #5 TOCTOU audit: document or fix the index-entry race during revalidation/cleanup (cache.ex:237-246, swr.ex:342-351)
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Every cache read serializes through a single GenServer (cache.ex:48-52). Under load this is a hard bottleneck — ETS is already :set with read_concurrency so direct :ets.lookup is safe for read path.
<!-- SECTION:NOTES:END -->
