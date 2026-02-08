defmodule FrontendExWeb.CursorLinks do
  @moduledoc false

  # Builds deterministic query strings without double-encoding `cursor`.
  #
  # Important:
  # - `cursor_query` is the *decoded* cursor query string (it may contain `&` and `=`),
  #   e.g. `"items_count=50&block_number=123&index=0"`.
  # - This function will percent-encode it for transport as a single `cursor=` value.

  alias FrontendEx.Blockscout.Cursor

  @type param :: {String.t(), String.Chars.t()}

  @spec with_cursor(String.t(), String.t(), [param]) :: String.t()
  def with_cursor(path, cursor_query, extra_params \\ [])
      when is_binary(path) and is_binary(cursor_query) and is_list(extra_params) do
    {base_path, existing_query, fragment} = parse_path(path)

    cursor_value = Cursor.encode_cursor_value(cursor_query)

    params =
      []
      |> merge_query_string(existing_query)
      |> merge_params(extra_params)
      |> drop_key("cursor")
      |> dedupe_last()

    params =
      case cursor_value do
        nil -> params
        v -> [{"cursor", v} | params]
      end

    build_path(base_path, encode_query(params), fragment)
  end

  @spec without_cursor(String.t(), [param]) :: String.t()
  def without_cursor(path, extra_params \\ []) when is_binary(path) and is_list(extra_params) do
    {base_path, existing_query, fragment} = parse_path(path)

    params =
      []
      |> merge_query_string(existing_query)
      |> merge_params(extra_params)
      |> drop_key("cursor")
      |> dedupe_last()

    build_path(base_path, encode_query(params), fragment)
  end

  defp parse_path(path) do
    uri = URI.parse(path)

    base_path =
      case uri.path do
        nil ->
          # URI.parse/1 leaves path nil for some invalid inputs; fall back to a safe split.
          path
          |> String.split(["?", "#"], parts: 2)
          |> List.first()
          |> to_string()

        p ->
          p
      end

    {base_path, uri.query, uri.fragment}
  end

  defp build_path(base_path, query, fragment) do
    base_path =
      case base_path do
        "" -> "/"
        other -> other
      end

    base_path
    |> then(fn p ->
      if query == "" do
        p
      else
        p <> "?" <> query
      end
    end)
    |> then(fn p ->
      if is_binary(fragment) and fragment != "" do
        p <> "#" <> fragment
      else
        p
      end
    end)
  end

  defp merge_query_string(params, nil), do: params

  defp merge_query_string(params, query) when is_binary(query) do
    query
    |> URI.query_decoder()
    |> Enum.reduce(params, fn {k, v}, acc -> [{k, v} | acc] end)
    |> Enum.reverse()
  end

  defp merge_params(params, extra_params) when is_list(extra_params) do
    extra_params =
      Enum.flat_map(extra_params, fn
        {_k, v} when is_nil(v) -> []
        {k, v} -> [{to_string(k), v}]
      end)

    params ++ extra_params
  end

  defp drop_key(params, key) when is_list(params) and is_binary(key) do
    Enum.reject(params, fn {k, _v} -> to_string(k) == key end)
  end

  defp dedupe_last(params) do
    {out, _seen} =
      params
      |> Enum.reverse()
      |> Enum.reduce({[], MapSet.new()}, fn {k, v}, {acc, seen} ->
        k = to_string(k)

        if MapSet.member?(seen, k) do
          {acc, seen}
        else
          {[{k, v} | acc], MapSet.put(seen, k)}
        end
      end)

    out
  end

  defp encode_query(params) do
    params
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.map(fn
      {"cursor", v} ->
        # Cursor value is already percent-encoded by Cursor.encode_cursor_value/1.
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
