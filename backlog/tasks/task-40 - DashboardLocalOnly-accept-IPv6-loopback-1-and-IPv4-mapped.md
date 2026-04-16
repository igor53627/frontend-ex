---
id: TASK-40
title: 'DashboardLocalOnly: accept IPv6 loopback (::1 and IPv4-mapped)'
status: To Do
assignee: []
created_date: '2026-04-16 19:21'
labels:
  - elixir
  - security
dependencies: []
references:
  - lib/frontend_ex_web/plugs/dashboard_local_only.ex
priority: low
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 plugs/dashboard_local_only.ex grants access for ::1 and ::ffff:127.0.0.1 in addition to 127.0.0.1/localhost
- [ ] #2 Plug test covers each loopback variant
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
plugs/dashboard_local_only.ex:14 — dual-stack hosts can route to dashboard as ::1; current check misses it.
<!-- SECTION:NOTES:END -->
