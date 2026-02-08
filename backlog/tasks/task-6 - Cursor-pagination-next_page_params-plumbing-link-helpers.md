---
id: TASK-6
title: 'Cursor pagination: next_page_params plumbing + link helpers'
status: Done
assignee: []
created_date: '2026-02-08 13:37'
updated_date: '2026-02-08 19:48'
labels:
  - api
  - pagination
dependencies:
  - TASK-1
  - TASK-5
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Helper encodes/decodes `next_page_params` into query string
- [x] #2 UI builds Next/Prev links from cursor only (no fake page numbers)
- [x] #3 Round-trip tests for cursor params
<!-- AC:END -->
