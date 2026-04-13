# Agent Guidelines

Project-specific guidance for AI coding agents working on `frontend-ex`.

## Project overview

Phoenix SSR app replacing `fast-frontend` (Rust/Axum/Askama) with byte-for-byte HTML parity per skin. Uses `.html.eex` templates (not HEEx) for parity-critical rendering.

## Build and test

- `mix setup` to install dependencies
- `mix test` to run all tests
- `mix precommit` to run the full pre-commit suite (compile --warnings-as-errors, deps.unlock --unused, format, test)

## Key conventions

- Use `Req` for HTTP requests (already included). Do not use `:httpoison`, `:tesla`, or `:httpc`.
- Parity routes use `.html.eex` templates, not `.html.heex` (HEEx). This is intentional for byte-level output control.
- `config :phoenix_template, :trim_on_html_eex_engine, false` must remain set.
- Blockscout API client uses a pluggable request adapter (real HTTP in dev/prod, fixture files in test).

## Elixir guidelines

- Lists do not support index-based access via `[]` syntax. Use `Enum.at/2` or pattern matching.
- Never nest multiple modules in the same file.
- Don't use `String.to_atom/1` on user input.
- In tests, always use `start_supervised!/1` for process cleanup. Avoid `Process.sleep/1`.
