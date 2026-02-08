defmodule FrontendEx.Blockscout.Cursor do
  @moduledoc false

  alias Jason.OrderedObject

  @type next_page_params ::
          nil
          | OrderedObject.t()
          | %{optional(String.t()) => term()}
          | [{String.t(), term()}]

  @doc """
  Converts Blockscout `next_page_params` into a query string, preserving key order
  when possible (ordered object / list input).

  Each key/value is percent-encoded (space is `%20`, not `+`), matching Rust's
  `urlencoding::encode` behavior.
  """
  @spec next_page_params_query(next_page_params()) :: String.t() | nil
  def next_page_params_query(nil), do: nil

  def next_page_params_query(%OrderedObject{values: values}) do
    kv_pairs_query(values)
  end

  def next_page_params_query(%{} = map) do
    # Maps do not preserve insertion order; sort for deterministic output.
    map
    |> Enum.sort_by(fn {k, _v} -> to_string(k) end)
    |> kv_pairs_query()
  end

  def next_page_params_query(values) when is_list(values) do
    kv_pairs_query(values)
  end

  @doc """
  Encodes `next_page_params` for transport as a single `cursor=` query param.

  This performs two layers:
  1. Encode key/value pairs into a query string: `k=v&k2=v2...`
  2. Percent-encode the full query string so `&` doesn't break query parsing.
  """
  @spec encode_next_page_params(next_page_params()) :: String.t() | nil
  def encode_next_page_params(next_page_params) do
    next_page_params
    |> next_page_params_query()
    |> encode_cursor_value()
  end

  @doc """
  Percent-encodes a full cursor query string for safe placement into `cursor=...`.
  """
  @spec encode_cursor_value(String.t() | nil) :: String.t() | nil
  def encode_cursor_value(nil), do: nil

  def encode_cursor_value(query_string) when is_binary(query_string) do
    query_string
    |> String.trim()
    |> case do
      "" -> nil
      qs -> URI.encode(qs, &URI.char_unreserved?/1)
    end
  end

  @doc """
  Decodes an encoded cursor value back into a query string.

  Note: Phoenix/Plug already URL-decodes query params, so if you're reading
  `conn.params["cursor"]` you typically DO NOT want to call this function.
  """
  @spec decode_cursor_value(String.t() | nil) :: {:ok, String.t()} | :error
  def decode_cursor_value(nil), do: :error

  def decode_cursor_value(cursor_value) when is_binary(cursor_value) do
    cursor_value = String.trim(cursor_value)

    if cursor_value == "" do
      :error
    else
      try do
        {:ok, URI.decode(cursor_value)}
      rescue
        ArgumentError -> :error
      end
    end
  end

  defp kv_pairs_query(pairs) when is_list(pairs) do
    parts =
      pairs
      |> Enum.reduce([], fn
        {k, v}, acc ->
          case normalize_value(v) do
            {:ok, vs} ->
              ks = encode_component(k)
              vs = encode_component(vs)
              [ks <> "=" <> vs | acc]

            :skip ->
              acc
          end
      end)
      |> Enum.reverse()

    case parts do
      [] -> nil
      _ -> Enum.join(parts, "&")
    end
  end

  defp encode_component(value) do
    value
    |> to_string()
    |> URI.encode(&URI.char_unreserved?/1)
  end

  defp normalize_value(v) when is_binary(v), do: {:ok, v}
  defp normalize_value(v) when is_integer(v), do: {:ok, Integer.to_string(v)}
  defp normalize_value(v) when is_float(v), do: {:ok, to_string(v)}
  defp normalize_value(v) when is_boolean(v), do: {:ok, to_string(v)}
  defp normalize_value(nil), do: :skip
  defp normalize_value(_), do: :skip
end
