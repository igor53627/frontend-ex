---
id: TASK-24
title: 'Address tabs: /address/:address/* (tokens/transfers/internal)'
status: To Do
assignee: []
created_date: '2026-02-09 15:04'
labels:
  - pages
  - address
  - parity
dependencies:
  - TASK-5
  - TASK-7
  - TASK-9
  - TASK-15
priority: high
---

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 GET /address/:address/tokens renders SSR (classic)
- [ ] #2 GET /address/:address/token-transfers renders SSR (classic)
- [ ] #3 GET /address/:address/internal renders SSR (classic)
<!-- AC:END -->

## Description

The Classic address page has tabs that currently point to missing routes in `frontend-ex`. Port these “address tab” pages from Rust (Classic skin only):

- `/address/:address/tokens`
- `/address/:address/token-transfers`
- `/address/:address/internal`

## Implementation Notes

- Rust reference: `fast-frontend/src/handlers/address_tabs.rs` and templates:
- `fast-frontend/templates/classic/address_tokens.html`
- `fast-frontend/templates/classic/address_token_transfers.html`
- `fast-frontend/templates/classic/address_internal.html`
- Blockscout API endpoints:
- `/api/v2/addresses/<address>`
- `/api/v2/addresses/<address>/tokens`
- `/api/v2/addresses/<address>/token-transfers`
- `/api/v2/addresses/<address>/internal-transactions`
- `/api/v2/stats` (coin_price/gas_price header)
- Keep SSR output byte-for-byte with Rust using golden fixtures.
