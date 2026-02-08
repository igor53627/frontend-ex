---
id: TASK-8
title: Stale-while-revalidate cache (5s fresh / 20s stale)
status: Done
assignee: []
created_date: '2026-02-08 13:37'
updated_date: '2026-02-08 23:47'
labels:
  - cache
  - swr
dependencies:
  - TASK-7
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 0-5s: serve fresh from cache
- [x] #2 5-20s: serve stale and refresh in background
- [x] #3 >20s: fetch fresh before serving
- [x] #4 Refresh deduped per key
- [x] #5 Unit tests cover SWR timing behavior
<!-- AC:END -->
