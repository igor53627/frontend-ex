defmodule FrontendEx.Blockscout.Client do
  @moduledoc false

  @timeout_ms 10_000
  @retry_sleep_ms 250

  @type error ::
          :not_found
          | {:http_status, non_neg_integer(), binary()}
          | {:transport, term()}

  @spec get_json(binary()) :: {:ok, term()} | {:error, error()}
  def get_json(path) when is_binary(path) do
    with {:ok, url} <- build_url(blockscout_api_url!(), path) do
      case fetch_json_with_retry(url, 0) do
        {:ok, json} ->
          {:ok, json}

        {:error, _} = err ->
          err
      end
    else
      {:error, reason} ->
        {:error, {:transport, reason}}
    end
  end

  # Retry semantics intentionally mirror fast-frontend (Rust):
  # - transport errors: retry once (attempt 0 -> 1)
  # - 429/5xx: retry once (attempt 0 -> 1)
  # - invalid JSON in 2xx: retry twice (3 attempts total)
  defp fetch_json_with_retry(url, attempt) when attempt in 0..2 do
    case request_raw(url) do
      {:ok, %Req.Response{status: status, body: body}}
      when status >= 200 and status <= 299 and is_binary(body) ->
        case Jason.decode(body) do
          {:ok, json} ->
            {:ok, json}

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

  defp request_raw(url) when is_binary(url) do
    Req.new(
      url: url,
      finch: FrontendEx.Finch,
      # Disable Req's built-in retries; we implement Rust-matching semantics above.
      retry: false,
      # Keep raw bytes, decode JSON ourselves for consistent error mapping.
      decode_body: false,
      # Rust uses 10s total timeout; replicate via connect + receive timeouts.
      receive_timeout: @timeout_ms,
      headers: [
        {"accept", "application/json"}
      ]
    )
    |> Req.get()
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
end
