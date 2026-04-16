defmodule FrontendExWeb.Pagination do
  @moduledoc """
  Shared pagination helpers for parity controllers.

  Exposed via the `:controller` macro in `frontend_ex_web.ex`.

  Upstream cursor formats vary per endpoint (txs merges with params, token
  sanitizes to a safe subset, nft normalizes an opaque token), so the
  cursor-shape logic stays controller-local. Only the bits that are truly
  shared live here:

    * `normalize_page_size/3` — clamp `"ps"`/`"limit"` params to an allowed set
    * `normalize_cursor_param/1` — trim/empty-guard an opaque cursor string
  """

  @doc """
  Resolves a page-size param (`"ps"` or `"limit"`) against an allow-list.

  Returns the parsed value if it's in `options`, otherwise `default`. Accepts
  integers or decimal strings (trimmed). Any other shape falls back to `default`.
  """
  @spec normalize_page_size(map(), [pos_integer()], pos_integer()) :: pos_integer()
  def normalize_page_size(params, options, default)
      when is_map(params) and is_list(options) and is_integer(default) do
    raw = Map.get(params, "ps") || Map.get(params, "limit") || ""

    parsed =
      case raw do
        v when is_integer(v) -> v
        v when is_binary(v) -> Integer.parse(String.trim(v))
        _ -> :error
      end

    value =
      case parsed do
        v when is_integer(v) -> v
        {v, ""} when is_integer(v) -> v
        _ -> default
      end

    if value in options, do: value, else: default
  end

  @doc """
  Normalizes an opaque cursor parameter.

  Returns the trimmed string, or `nil` for empty/nil/non-binary input.
  """
  @spec normalize_cursor_param(term()) :: binary() | nil
  def normalize_cursor_param(nil), do: nil

  def normalize_cursor_param(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  def normalize_cursor_param(_), do: nil
end
