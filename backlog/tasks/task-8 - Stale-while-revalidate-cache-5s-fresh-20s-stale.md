---
id: TASK-8
title: Stale-while-revalidate cache (5s fresh / 20s stale)
status: To Do
assignee: []
created_date: '2026-02-08 13:37'
labels:
  - cache
  - swr
dependencies:
  - TASK-7
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 0-5s: serve fresh from cache
- [ ] #2 5-20s: serve stale and refresh in background
- [ ] #3 >20s: fetch fresh before serving
- [ ] #4 Refresh deduped per key
- [ ] #5 Unit tests cover SWR timing behavior
<!-- AC:END -->
