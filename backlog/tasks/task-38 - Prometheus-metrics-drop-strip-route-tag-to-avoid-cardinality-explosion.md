---
id: TASK-38
title: 'Prometheus metrics: drop/strip :route tag to avoid cardinality explosion'
status: Done
assignee: []
created_date: '2026-04-16 19:21'
updated_date: '2026-04-16 20:17'
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
- [x] #1 router_dispatch metrics in telemetry.ex do not tag by raw :route (path-params explode label cardinality)
- [x] #2 If route context is needed, use normalized route template (controller+action) instead of resolved path
- [x] #3 Verify in LiveDashboard/metrics endpoint that label cardinality is bounded by route count, not request count
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
telemetry.ex:52, 58, 64 use tags: [:route]. Every unique URL becomes a Prometheus label — DoS/ops risk at scale.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Audit invalidated the original premise. Phoenix's `[:phoenix, :router_dispatch, :stop]` telemetry emits `:route` as the matched route **template** (e.g. `/block/:id`), not the resolved URL — confirmed at `deps/phoenix/lib/phoenix/router.ex:647` where the emitted metadata pair is `route: path` with `path` being the route's template. Cardinality is bounded by route count (~15 defined routes in this app), not request count. No DoS/ops risk.

No code change needed. Added an inline comment to `telemetry.ex` so future readers don't re-audit this concern.

Addresses TASK-38
<!-- SECTION:FINAL_SUMMARY:END -->
