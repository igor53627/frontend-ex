---
id: decision-1
title: Templating strategy for byte-for-byte HTML parity
date: '2026-02-08 14:31'
status: proposed
---
## Context

We are migrating `fast-frontend` (Rust/Axum/Askama) to `frontend-ex` (Elixir/Phoenix) and want server-rendered HTML with byte-for-byte parity versus the Rust output (per skin).

Key constraints:

- The existing templates include significant inline CSS/JS and rely on precise whitespace/attribute rendering.
- Blockscout API uses cursor pagination (`next_page_params`), and cursor values must be carried through links without breaking query parsing.
- Askama escapes values by default; templates selectively mark output as safe (`|safe`).

## Decision

1. Use `.html.eex` templates for migrated pages and layouts.
   - Avoid `.heex` for parity-critical templates to prevent:
     - dev-only HEEx annotations (`data-phx-*`)
     - component rendering that may alter escaping/whitespace

2. Convert Askama template inheritance to explicit Phoenix “layout + fragments”.
   - For each skin, create a root layout template that is a 1:1 conversion of:
     - `fast-frontend/templates/classic/base.html`
     - `fast-frontend/templates/53627/base.html`
   - Replace `{% block ... %}` with assigns:
     - `@page_title`, `@head_meta`, `@styles`, `@scripts`
     - nav “active” blocks as string assigns (`"active"` or `""`) to preserve spaces exactly
     - `@inner_content` for the content block

3. Escaping rules:
   - Default: render dynamic values as escaped text.
   - Only render raw HTML where Rust templates used `|safe` (via `Phoenix.HTML.raw/1` or safe iodata).
   - Avoid Phoenix HTML helpers (`link`, form builders, etc.) in ported templates; write raw HTML tags to match output.

4. Development tooling:
   - For parity tests, run in `MIX_ENV=test` (no LiveReloader injection).
   - Use golden snapshot tests to assert byte-for-byte output.

## Consequences

Pros:

- Maximum control over output; minimizes “framework formatting” differences.
- Mirrors the original templates closely, making 1:1 porting mechanical.

Cons:

- Porting effort: Askama syntax must be converted to EEx.
- Less idiomatic Phoenix (minimal components/helpers).
- Requires discipline: any helper/component usage risks breaking byte-for-byte parity.
