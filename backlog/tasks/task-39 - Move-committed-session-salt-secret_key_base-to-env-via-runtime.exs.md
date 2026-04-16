---
id: TASK-39
title: Move committed session salt + secret_key_base to env via runtime.exs
status: Done
assignee: []
created_date: '2026-04-16 19:21'
updated_date: '2026-04-16 20:20'
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
- [x] #1 Session signing salt no longer hardcoded in router.ex/endpoint.ex; read from SECRET_KEY_BASE / SESSION_SIGNING_SALT env in runtime.exs
- [x] #2 config/test.exs uses a clearly-marked test value (or reads a defaulted env) — documentation notes it's test-only
- [x] #3 Production deploy script/docs updated with required env vars
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
router.ex:8-13 commits a session signing salt; config/test.exs:7 commits secret_key_base. Session is unused by parity routes, but committing looks like prod-hygiene debt.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Pulled the committed session signing salts out of the code tree:
- `router.ex` now reads `Application.compile_env(:frontend_ex, :session_signing_salt, ...)`. Dev/test keep the dev-only placeholder via `config/config.exs`.
- `config.exs` similarly defaults `live_view: [signing_salt: ...]` to the dev-only placeholder.
- `config/prod.exs` raises at build time unless `SESSION_SIGNING_SALT` and `LIVE_VIEW_SIGNING_SALT` env vars are set (Phoenix session options are compile-time, so they must be resolved when `mix release` runs — not at runtime via `runtime.exs`).
- `config/test.exs` has an explicit comment stating the committed `secret_key_base` is a fixed test-only value required by `Phoenix.Endpoint` even with `server: false`.
- Updated `docs/DEPLOYMENT.md` (release build instructions) and `docs/FEATURE_FLAGS.md` to document the new build-time env vars.

Addresses TASK-39
<!-- SECTION:FINAL_SUMMARY:END -->
