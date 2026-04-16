defmodule FrontendEx.Blockscout.Client do
  @moduledoc false

  alias Jason.OrderedObject

  @api_cache FrontendEx.ApiCache
  @api_swr_cache FrontendEx.ApiSWRCache

  @standard_ttl_ms 60_000
  @negative_ttl_ms 5_000
  @swr_fresh_ms 5_000
  @swr_stale_ms 20_000

  @retry_sleep_ms 250

  @type error ::
          :not_found
          | {:http_status, non_neg_integer(), binary()}
          | {:transport, term()}

  @spec get_json(binary()) :: {:ok, term()} | {:error, error()}
  def get_json(path) when is_binary(path) do
    get_json_uncached(path)
  end

  @spec get_json_uncached(binary()) :: {:ok, term()} | {:error, error()}
  def get_json_uncached(path) when is_binary(path) do
    with {:ok, url} <- build_url(blockscout_api_url!(), path) do
      fetch_json_with_retry(url, 0)
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @spec get_json_cached(binary(), term()) :: {:ok, term()} | {:error, error()}
  def get_json_cached(path, context) when is_binary(path) do
    get_json_cached(path, context, @standard_ttl_ms)
  end

  @spec get_json_cached(binary(), term(), non_neg_integer()) :: {:ok, term()} | {:error, error()}
  def get_json_cached(path, context, ttl_ms)
      when is_binary(path) and is_integer(ttl_ms) and ttl_ms >= 0 do
    with {:ok, url} <- build_url(blockscout_api_url!(), path) do
      get_json_cached_url(url, context, ttl_ms)
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  @spec get_json_cached_at(binary(), binary(), term()) :: {:ok, term()} | {:error, error()}
  def get_json_cached_at(base_url, path, context)
      when is_binary(base_url) and is_binary(path) do
    get_json_cached_at(base_url, path, context, @standard_ttl_ms)
  end

  @spec get_json_cached_at(binary(), binary(), term(), non_neg_integer()) ::
          {:ok, term()} | {:error, error()}
  def get_json_cached_at(base_url, path, context, ttl_ms)
      when is_binary(base_url) and is_binary(path) and is_integer(ttl_ms) and ttl_ms >= 0 do
    with {:ok, url} <- build_url(base_url, path) do
      get_json_cached_url(url, context, ttl_ms)
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  defp get_json_cached_url(url, context, ttl_ms)
       when is_binary(url) and is_integer(ttl_ms) and ttl_ms >= 0 do
    # Cache keys must include any inputs that can vary the upstream response
    # (auth headers, locale, etc). Callers must supply a context.
    pos_key = {context, :pos, url}
    neg_key = {context, :neg, url}

    cache = api_cache_server()

    case FrontendEx.Cache.get(cache, pos_key) do
      {:ok, json} ->
        {:ok, json}

      :error ->
        case FrontendEx.Cache.get(cache, neg_key) do
          {:ok, true} ->
            {:error, :not_found}

          :error ->
            result =
              FrontendEx.Cache.get_or_fetch(cache, pos_key, ttl_ms, fn ->
                fetch_json_with_retry(url, 0)
              end)

            case result do
              {:ok, json} ->
                {:ok, json}

              {:error, :not_found} ->
                _ = FrontendEx.Cache.put(cache, neg_key, true, @negative_ttl_ms)
                {:error, :not_found}

              {:error, {:http_status, _, _} = err} ->
                {:error, err}

              {:error, {:transport, _} = err} ->
                {:error, err}

              {:error, other} ->
                {:error, {:transport, {:cache_fetch_failed, other}}}
            end
        end
    end
  end

  @spec get_json_swr(binary(), term(), non_neg_integer(), non_neg_integer()) ::
          {:ok, term()} | {:error, error()}
  def get_json_swr(path, context, fresh_ms \\ @swr_fresh_ms, stale_ms \\ @swr_stale_ms)

  def get_json_swr(path, context, fresh_ms, stale_ms)
      when is_binary(path) and is_integer(fresh_ms) and fresh_ms >= 0 and is_integer(stale_ms) and
             stale_ms >= 0 and stale_ms >= fresh_ms do
    with {:ok, url} <- build_url(blockscout_api_url!(), path) do
      key = {context, fresh_ms, stale_ms, url}

      FrontendEx.Cache.SWR.get_or_fetch(api_swr_cache_server(), key, fresh_ms, stale_ms, fn ->
        fetch_json_with_retry(url, 0)
      end)
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  def get_json_swr(_path, _context, fresh_ms, stale_ms)
      when is_integer(fresh_ms) and fresh_ms >= 0 and is_integer(stale_ms) and stale_ms >= 0 and
             stale_ms < fresh_ms do
    {:error, {:transport, :invalid_window}}
  end

  # Retry semantics intentionally mirror fast-frontend (Rust):
  # - transport errors: retry once (attempt 0 -> 1)
  # - 429/5xx: retry once (attempt 0 -> 1)
  # - invalid JSON in 2xx: retry twice (3 attempts total)
  defp fetch_json_with_retry(url, attempt) when attempt in 0..2 do
    case request_raw(url) do
      {:ok, %Req.Response{status: status, body: body}}
      when status >= 200 and status <= 299 and is_binary(body) ->
        # Blockscout occasionally returns objects with duplicate keys (observed in
        # `next_page_params`). Different JSON parsers resolve duplicates
        # differently; decode as ordered objects and normalize so the *last*
        # occurrence wins, matching `jq` and serde_json behavior.
        case Jason.decode(body, objects: :ordered_objects) do
          {:ok, json} ->
            {:ok, normalize_json(json)}

          {:error, _} ->
            if attempt < 2 do
              Process.sleep(@retry_sleep_ms)
              fetch_json_with_retry(url, attempt + 1)
            else
              # Match Rust behavior: invalid JSON after retries is treated as not found.
              {:error, :not_found}
            end
        end

      {:ok, %Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Req.Response{status: status}}
      when (status == 429 or (status >= 500 and status <= 599)) and attempt == 0 ->
        Process.sleep(@retry_sleep_ms)
        fetch_json_with_retry(url, attempt + 1)

      {:ok, %Req.Response{status: status, body: body}}
      when is_integer(status) and is_binary(body) ->
        {:error, {:http_status, status, body}}

      {:ok, %Req.Response{status: status, body: body}} when is_integer(status) ->
        {:error, {:http_status, status, to_string(body)}}

      {:error, %Req.TransportError{reason: _reason}} when attempt == 0 ->
        Process.sleep(@retry_sleep_ms)
        fetch_json_with_retry(url, attempt + 1)

      {:error, %Req.TransportError{reason: reason}} ->
        {:error, {:transport, reason}}

      {:error, other} ->
        {:error, {:transport, other}}
    end
  end

  defp normalize_json(%OrderedObject{values: values}) do
    Enum.reduce(values, %{}, fn {k, v}, acc ->
      Map.put(acc, k, normalize_json(v))
    end)
  end

  defp normalize_json(%{} = map) do
    Map.new(map, fn {k, v} -> {k, normalize_json(v)} end)
  end

  defp normalize_json(list) when is_list(list) do
    Enum.map(list, &normalize_json/1)
  end

  defp normalize_json(other), do: other

  defp request_raw(url) when is_binary(url) do
    request_adapter().request_raw(url)
  end

  # Tests swap the adapter via `Application.put_env/3` (see
  # `test/frontend_ex/blockscout/client_test.exs`), so this stays read-through
  # rather than being cached in `:persistent_term` — a cache would serve a
  # stale adapter after test-side mutation. The lookup is an ETS read
  # (sub-microsecond); not a meaningful hot-path cost.
  defp request_adapter do
    Application.get_env(
      :frontend_ex,
      :blockscout_request_adapter,
      FrontendEx.Blockscout.RequestAdapter.Req
    )
  end

  defp blockscout_api_url! do
    Application.get_env(:frontend_ex, :blockscout_api_url) ||
      raise "missing :frontend_ex, :blockscout_api_url runtime config (BLOCKSCOUT_API_URL)"
  end

  defp build_url(base_url, path) when is_binary(base_url) and is_binary(path) do
    base_url = String.trim(base_url) |> String.trim_trailing("/")
    path = String.trim(path)
    path = if String.starts_with?(path, "/"), do: path, else: "/" <> path
    url = base_url <> path

    if String.match?(url, ~r/\s/u) do
      {:error, :invalid_url}
    else
      {:ok, url}
    end
  end

  defp api_cache_server do
    Application.get_env(:frontend_ex, :blockscout_api_cache_server) || @api_cache
  end

  defp api_swr_cache_server do
    Application.get_env(:frontend_ex, :blockscout_api_swr_cache_server) || @api_swr_cache
  end
end
