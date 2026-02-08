# ADR 0001: Templating Strategy for Byte-for-Byte HTML Parity

Date: 2026-02-08

## Context

We are migrating `fast-frontend` (Rust/Axum/Askama) to `frontend-ex` (Elixir/Phoenix). The migration goal is server-rendered HTML with byte-for-byte parity versus the Rust output (per skin).

Constraints:

- Existing templates include significant inline CSS/JS and rely on precise whitespace/attribute rendering.
- Cursor pagination values must be carried in links without breaking query parsing.

## Decision

1. Use `.html.eex` templates for parity-critical rendering.
   - Avoid HEEx for parity routes to minimize framework-driven whitespace and attribute rendering differences.

2. Convert Askama template inheritance to a Phoenix "root layout + fragments" approach.
   - Maintain a skin-specific root layout that matches Rust `base.html` per skin.
   - Render content via assigns/partial templates rather than HEEx components.

3. Preserve whitespace and output fidelity.
   - Disable EEx HTML trimming: `config :phoenix_template, :trim_on_html_eex_engine, false`
   - Trim the final trailing newline in responses for parity with Askama output.

## Consequences

Pros:

- Maximum control of rendered output and deterministic whitespace.
- Mechanical, low-risk template porting.

Cons:

- Less idiomatic Phoenix templates/components for parity-critical pages.

