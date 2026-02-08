---
id: TASK-4
title: Templating strategy for byte-for-byte HTML parity
status: Done
assignee: []
created_date: '2026-02-08 13:37'
updated_date: '2026-02-08 15:34'
labels:
  - templates
  - parity
dependencies:
  - TASK-1
  - TASK-3
documentation:
  - backlog/decisions
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Decision: backlog/decisions/decision-1 - Templating-strategy-for-byte-for-byte-HTML-parity.md

Representative parity implemented:
- Route: GET /exportData (classic)
- Golden: test/golden/exportData.classic.rust.html
- Test: test/frontend_ex_web/export_data_parity_test.exs

Notes:
- config/config.exs sets :phoenix_template, :trim_on_html_eex_engine = false to avoid whitespace trimming.
- fast_browser pipeline trims trailing newlines to match Askama output.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 Decision documented: EEx/HEEx strategy + escaping rules
- [x] #2 One representative page renders byte-for-byte vs Rust given same fixture data
<!-- AC:END -->
