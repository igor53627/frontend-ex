---
id: TASK-3
title: 'Scaffold Phoenix app (SSR, no DB) + runtime env config'
status: Done
assignee: []
created_date: '2026-02-08 13:37'
updated_date: '2026-02-08 14:29'
labels:
  - setup
  - phoenix
dependencies:
  - TASK-2
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Phoenix scaffolded (no Ecto, no Live, no assets pipeline).

Runtime config added in config/runtime.exs:
- LISTEN_ADDR parsing (ip:port) for Endpoint bind
- BLOCKSCOUT_API_URL/BLOCKSCOUT_URL/BASE_URL/FF_SKIN stored in app env

Verified:
- LISTEN_ADDR=127.0.0.1:3010 serves HTTP
- BLOCKSCOUT_API_URL overrides are visible at runtime
- mix test passes
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Phoenix app generated in-repo (no DB)
- [x] #2 `LISTEN_ADDR=127.0.0.1:3010` binds correctly
- [x] #3 `BLOCKSCOUT_API_URL` is runtime-configurable
- [x] #4 `mix test` runs
<!-- AC:END -->
