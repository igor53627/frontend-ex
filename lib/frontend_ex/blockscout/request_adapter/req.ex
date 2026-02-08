defmodule FrontendEx.Blockscout.RequestAdapter.Req do
  @moduledoc false

  @behaviour FrontendEx.Blockscout.RequestAdapter

  @timeout_ms 10_000

  @impl true
  def request_raw(url) when is_binary(url) do
    Req.new(
      url: url,
      finch: FrontendEx.Finch,
      # Disable Req's built-in retries; the client implements Rust-matching semantics.
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
end
