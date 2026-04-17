defmodule FrontendEx.Version do
  @moduledoc """
  Release version metadata surfaced in the footer for operational visibility.

  * `app/0` — semver from `mix.exs` (baked at compile time)
  * `sha/0` — short git SHA from the `GIT_SHA` env var at *build* time, or
    `"dev"` when unset. `deploy.sh` forwards the SHA; release builders
    should set it explicitly.
  * `display/0` — formatted for display (`"v0.2.0·abc1234"`)
  """

  @compiled_app Mix.Project.config()[:version] || "0.0.0"

  @compiled_sha (case System.get_env("GIT_SHA") do
                   nil ->
                     "dev"

                   "" ->
                     "dev"

                   sha ->
                     sha |> String.trim() |> String.slice(0, 12)
                 end)

  @spec app() :: binary()
  def app, do: Application.get_env(:frontend_ex, :app_version_override, @compiled_app)

  @spec sha() :: binary()
  def sha, do: Application.get_env(:frontend_ex, :git_sha_override, @compiled_sha)

  @spec display() :: binary()
  def display, do: "v#{app()}·#{sha()}"
end
