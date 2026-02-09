---
id: TASK-11
title: 'Home page (blocks list via SWR, SSR, byte-for-byte)'
status: Done
assignee: []
created_date: '2026-02-08 13:37'
updated_date: '2026-02-09 05:41'
labels:
  - pages
  - home
  - swr
  - parity
dependencies:
  - TASK-5
  - TASK-8
  - TASK-9
  - TASK-15
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Home page renders server-side
- [x] #2 Blocks list uses SWR cache semantics
- [x] #3 HTML snapshot matches Rust byte-for-byte (fixtures)
<!-- AC:END -->
