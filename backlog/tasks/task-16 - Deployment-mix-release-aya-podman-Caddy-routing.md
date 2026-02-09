---
id: TASK-16
title: 'Deployment: mix release + aya (podman) + Caddy routing'
status: Done
assignee: []
created_date: '2026-02-08 13:38'
updated_date: '2026-02-09 10:55'
labels:
  - deploy
  - ops
dependencies:
  - TASK-3
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `mix release` builds a runnable release
- [x] #2 Deploy script copies release to aya and (re)starts service
- [x] #3 Caddy config updated + restart command documented
- [x] #4 Rollback procedure documented
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added aya deployment scaffolding (deploy.sh + systemd unit/env + Caddy snippet) and documented release build, restart, and rollback; verified MIX_ENV=prod mix release --overwrite builds a runnable release.
<!-- SECTION:FINAL_SUMMARY:END -->
