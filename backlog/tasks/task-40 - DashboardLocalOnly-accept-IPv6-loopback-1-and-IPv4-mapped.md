---
id: TASK-40
title: 'DashboardLocalOnly: accept IPv6 loopback (::1 and IPv4-mapped)'
status: Done
assignee: []
created_date: '2026-04-16 19:21'
updated_date: '2026-04-16 20:14'
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
- [x] #1 plugs/dashboard_local_only.ex grants access for ::1 and ::ffff:127.0.0.1 in addition to 127.0.0.1/localhost
- [x] #2 Plug test covers each loopback variant
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
plugs/dashboard_local_only.ex:14 — dual-stack hosts can route to dashboard as ::1; current check misses it.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added `{0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001}` match clause for IPv4-mapped IPv6 `::ffff:127.0.0.1`. The plug already accepted `::1`; this was the missing variant dual-stack sockets present when a request comes in over IPv6 but originated on v4 loopback.

Added 3 plug tests: `::1` allow, `::ffff:127.0.0.1` allow, `2001:db8::1` reject. All tests pass.

Addresses TASK-40
<!-- SECTION:FINAL_SUMMARY:END -->
