---
id: TASK-16
title: 'Deployment: mix release + aya (podman) + Caddy routing'
status: In Progress
assignee: []
created_date: '2026-02-08 13:38'
updated_date: '2026-02-09 10:15'
labels:
  - deploy
  - ops
dependencies:
  - TASK-3
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `mix release` builds a runnable release
- [ ] #2 Deploy script copies release to aya and (re)starts service
- [ ] #3 Caddy config updated + restart command documented
- [ ] #4 Rollback procedure documented
<!-- AC:END -->
