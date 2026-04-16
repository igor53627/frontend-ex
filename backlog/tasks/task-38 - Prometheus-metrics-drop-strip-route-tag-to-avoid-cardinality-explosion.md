---
id: TASK-38
title: 'Prometheus metrics: drop/strip :route tag to avoid cardinality explosion'
status: To Do
assignee: []
created_date: '2026-04-16 19:21'
labels:
  - elixir
  - ops
  - observability
dependencies: []
references:
  - lib/frontend_ex_web/telemetry.ex
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 router_dispatch metrics in telemetry.ex do not tag by raw :route (path-params explode label cardinality)
- [ ] #2 If route context is needed, use normalized route template (controller+action) instead of resolved path
- [ ] #3 Verify in LiveDashboard/metrics endpoint that label cardinality is bounded by route count, not request count
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
telemetry.ex:52, 58, 64 use tags: [:route]. Every unique URL becomes a Prometheus label — DoS/ops risk at scale.
<!-- SECTION:NOTES:END -->
