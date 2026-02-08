defmodule FrontendExWeb.CursorLinks do
  @moduledoc false

  # Builds deterministic query strings without double-encoding `cursor`.
  #
  # Cursor values should be produced by `FrontendEx.Blockscout.Cursor.encode_next_page_params/1`
  # and are already percent-encoded as a single query value.

  @spec with_cursor(String.t(), String.t(), [{String.t(), String.Chars.t()}]) :: String.t()
  def with_cursor(path, cursor_value, extra_params \\ [])
      when is_binary(path) and is_binary(cursor_value) and is_list(extra_params) do
    path <> "?" <> encode_query([{"cursor", cursor_value} | extra_params])
  end

  @spec without_cursor(String.t(), [{String.t(), String.Chars.t()}]) :: String.t()
  def without_cursor(path, extra_params \\ []) when is_binary(path) and is_list(extra_params) do
    case encode_query(extra_params) do
      "" -> path
      qs -> path <> "?" <> qs
    end
  end

  defp encode_query(pairs) do
    pairs
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn
      {"cursor", v} ->
        # Cursor is already percent-encoded; do NOT encode again.
        "cursor=" <> String.trim(to_string(v))

      {k, v} ->
        encode_component(k) <> "=" <> encode_component(v)
    end)
    |> Enum.reject(&(&1 == "cursor="))
    |> Enum.join("&")
  end

  defp encode_component(value) do
    value
    |> to_string()
    |> String.trim()
    |> URI.encode(&URI.char_unreserved?/1)
  end
end
