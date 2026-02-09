---
id: TASK-27
title: 'Monitoring: Prometheus metrics + LiveDashboard (local-only)'
status: Done
assignee: []
created_date: '2026-02-10 09:16'
updated_date: '2026-02-10 09:17'
labels:
  - ops
  - monitoring
dependencies:
  - TASK-16
  - TASK-18
references:
  - lib/frontend_ex_web/router.ex
  - lib/frontend_ex_web/telemetry.ex
  - lib/frontend_ex_web/plugs/dashboard_local_only.ex
documentation:
  - docs/DEPLOYMENT.md
  - docs/API_ENDPOINTS.md
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Expose Prometheus /metrics on localhost and scrape with telegraf
- [x] #2 Mount Phoenix LiveDashboard and access it via SSH port-forward
- [x] #3 Ensure LiveDashboard is not reachable through public Caddy proxy
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
- Prometheus metrics endpoint (localhost-only): `http://127.0.0.1:9568/metrics` (configurable via `FF_METRICS_ENABLED` and `FF_METRICS_PORT`).
- Telegraf on `aya` scrapes the metrics endpoint via `[[inputs.prometheus]]` (see `/mnt/sepolia/blockscout-proxy/telegraf.conf`).
- LiveDashboard is mounted at `/_dashboard` and is intentionally not reachable through the public Caddy proxy:
  - `FrontendExWeb.Plugs.DashboardLocalOnly` blocks requests with `Forwarded`/`X-Forwarded-*` headers and requires `conn.remote_ip` to be loopback.
  - Access via `ssh -L 4000:127.0.0.1:5174 aya` then open `http://localhost:4000/_dashboard`.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added Prometheus metrics export (telemetry) and a local-only Phoenix LiveDashboard for ad-hoc BEAM/Phoenix inspection; documented access and config.
<!-- SECTION:FINAL_SUMMARY:END -->
