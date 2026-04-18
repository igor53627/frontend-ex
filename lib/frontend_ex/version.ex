defmodule FrontendEx.Version do
  @moduledoc """
  Release version metadata surfaced in the footer for operational visibility.

  * `app/0` — semver from `mix.exs` (baked at compile time)
  * `sha/0` — short git SHA from the `GIT_SHA` env var at *build* time, or
    `"dev"` when unset. `deploy.sh` forwards the SHA; release builders
    should set it explicitly.
  * `backend/0` — upstream Blockscout version+commit, fetched from
    `/api/v2/health` via the shared cache (5-minute TTL). Returns a
    `%{version: binary(), sha: binary() | nil}` map if the upstream exposes
    `version`; `nil` if not. `sha` is `nil` for pre-0.4.4 blockscout-exex
    (before the `commit` field existed).
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

  # Backend version rarely changes; a 5-min TTL keeps upstream load minimal
  # without requiring a restart to pick up a new version.
  @backend_ttl_ms 300_000

  @spec app() :: binary()
  def app, do: Application.get_env(:frontend_ex, :app_version_override, @compiled_app)

  @spec sha() :: binary()
  def sha, do: Application.get_env(:frontend_ex, :git_sha_override, @compiled_sha)

  @spec backend() :: %{version: binary(), sha: binary() | nil} | nil
  def backend do
    case Application.get_env(:frontend_ex, :backend_version_override, :unset) do
      :unset -> fetch_backend()
      nil -> nil
      override when is_map(override) -> normalize_override(override)
      version when is_binary(version) -> %{version: strip_v_prefix(version), sha: nil}
    end
  end

  defp normalize_override(map) when is_map(map) do
    # Accept both atom-keyed and string-keyed overrides; normalize to atom
    # keys so callers can always `Map.get(x, :version)` safely.
    version = Map.get(map, :version) || Map.get(map, "version")
    sha = Map.get(map, :sha) || Map.get(map, "sha")

    cond do
      is_binary(version) and version != "" ->
        %{version: strip_v_prefix(version), sha: (is_binary(sha) and sha) || nil}

      true ->
        nil
    end
  end

  defp fetch_backend do
    case FrontendEx.Blockscout.Client.get_json_cached("/api/v2/health", :public, @backend_ttl_ms) do
      {:ok, resp} when is_map(resp) -> parse_health_response(resp)
      _ -> nil
    end
  end

  @doc """
  Parses a `/api/v2/health` response map into a `{version, sha}` map.

  Returns `nil` if the response is missing or malformed. Exposed for tests.
  """
  @spec parse_health_response(term()) :: %{version: binary(), sha: binary() | nil} | nil
  def parse_health_response(%{"version" => v} = resp) when is_binary(v) and v != "" do
    sha =
      case Map.get(resp, "commit") do
        s when is_binary(s) and s != "" -> String.slice(s, 0, 12)
        _ -> nil
      end

    %{version: strip_v_prefix(v), sha: sha}
  end

  def parse_health_response(_), do: nil

  # Strip a single leading `v`/`V` but only when followed by a digit — avoids
  # mangling strings like "version-1.2.3" while handling `v0.4.4` defensively.
  defp strip_v_prefix(<<c, d, _::binary>> = s)
       when (c == ?v or c == ?V) and d >= ?0 and d <= ?9 do
    binary_part(s, 1, byte_size(s) - 1)
  end

  defp strip_v_prefix(s) when is_binary(s), do: s

  @spec display() :: binary()
  def display, do: "v#{app()}·#{sha()}"
end
