---
id: TASK-39
title: Move committed session salt + secret_key_base to env via runtime.exs
status: To Do
assignee: []
created_date: '2026-04-16 19:21'
labels:
  - elixir
  - security
dependencies: []
references:
  - lib/frontend_ex_web/router.ex
  - lib/frontend_ex_web/endpoint.ex
  - config/test.exs
  - config/runtime.exs
priority: medium
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Session signing salt no longer hardcoded in router.ex/endpoint.ex; read from SECRET_KEY_BASE / SESSION_SIGNING_SALT env in runtime.exs
- [ ] #2 config/test.exs uses a clearly-marked test value (or reads a defaulted env) — documentation notes it's test-only
- [ ] #3 Production deploy script/docs updated with required env vars
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
router.ex:8-13 commits a session signing salt; config/test.exs:7 commits secret_key_base. Session is unused by parity routes, but committing looks like prod-hygiene debt.
<!-- SECTION:NOTES:END -->
