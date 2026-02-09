---
id: TASK-12
title: Block page (SSR + cursor pagination + byte-for-byte)
status: Done
assignee: []
created_date: '2026-02-08 13:37'
updated_date: '2026-02-09 10:25'
labels:
  - pages
  - block
  - parity
  - pagination
dependencies:
  - TASK-5
  - TASK-6
  - TASK-7
  - TASK-9
  - TASK-15
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Block details page renders SSR
- [x] #2 Any tx lists use cursor pagination (no fake page numbers)
- [x] #3 HTML snapshot matches Rust byte-for-byte (fixtures)
<!-- AC:END -->
