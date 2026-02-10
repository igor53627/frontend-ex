defmodule FrontendEx.Blockscout.ClientTest do
  use ExUnit.Case

  alias FrontendEx.Blockscout.Client

  setup do
    old_adapter = Application.get_env(:frontend_ex, :blockscout_request_adapter)
    old_stub_agent = Application.get_env(:frontend_ex, :blockscout_stub_agent)
    old_api_url = Application.get_env(:frontend_ex, :blockscout_api_url)

    Application.put_env(:frontend_ex, :blockscout_api_url, "http://stub")

    stub_agent =
      start_supervised!(
        Supervisor.child_spec(
          {Agent, fn -> %{script: %{}, calls: %{}} end},
          id: make_ref()
        )
      )

    Application.put_env(:frontend_ex, :blockscout_stub_agent, stub_agent)

    Application.put_env(
      :frontend_ex,
      :blockscout_request_adapter,
      FrontendEx.Blockscout.RequestAdapter.Stub
    )

    on_exit(fn ->
      if is_nil(old_adapter) do
        Application.delete_env(:frontend_ex, :blockscout_request_adapter)
      else
        Application.put_env(:frontend_ex, :blockscout_request_adapter, old_adapter)
      end

      if is_nil(old_stub_agent) do
        Application.delete_env(:frontend_ex, :blockscout_stub_agent)
      else
        Application.put_env(:frontend_ex, :blockscout_stub_agent, old_stub_agent)
      end

      if is_nil(old_api_url) do
        Application.delete_env(:frontend_ex, :blockscout_api_url)
      else
        Application.put_env(:frontend_ex, :blockscout_api_url, old_api_url)
      end
    end)

    {:ok, stub_agent: stub_agent}
  end

  defp put_script(agent, url, results) when is_binary(url) and is_list(results) do
    Agent.update(agent, fn %{script: script} = state ->
      %{state | script: Map.put(script, url, results)}
    end)
  end

  defp calls(agent, url) when is_binary(url) do
    Agent.get(agent, fn state ->
      state.calls |> Map.get(url, 0)
    end)
  end

  test "get_json_uncached/1 fetches and decodes JSON (stats endpoint)", %{stub_agent: agent} do
    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 200, body: ~s({"ok":true})}}
    ])

    assert {:ok, %{"ok" => true}} = Client.get_json_uncached("api/v2/stats")
    assert calls(agent, url) == 1
  end

  test "get_json_uncached/1 keeps the last occurrence for duplicate JSON keys", %{
    stub_agent: agent
  } do
    url = "http://stub/api/v2/transactions?items_count=50"

    # Observed in Blockscout `next_page_params`: duplicate keys for `index`/`block_number`.
    # We want last-wins semantics so cursor pagination advances.
    put_script(agent, url, [
      {:ok,
       %Req.Response{
         status: 200,
         body:
           ~s({"items":[],"next_page_params":{"index":50,"block_number":1,"items_count":50,"block_number":1,"index":0}})
       }}
    ])

    assert {:ok,
            %{
              "next_page_params" => %{
                "block_number" => 1,
                "index" => 0,
                "items_count" => 50
              }
            }} = Client.get_json_uncached("/api/v2/transactions?items_count=50")

    assert calls(agent, url) == 1
  end

  test "get_json_uncached/1 maps 404 to :not_found (tx endpoint)", %{stub_agent: agent} do
    url = "http://stub/api/v2/transactions/0xdead"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 404, body: "not found"}}
    ])

    assert {:error, :not_found} = Client.get_json_uncached("/api/v2/transactions/0xdead")
    assert calls(agent, url) == 1
  end

  test "get_json_uncached/1 retries once on 5xx then succeeds (blocks endpoint)", %{
    stub_agent: agent
  } do
    url = "http://stub/api/v2/blocks?limit=1"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 500, body: "upstream error"}},
      {:ok, %Req.Response{status: 200, body: ~s({"items":[{"height":1}]})}}
    ])

    assert {:ok, %{"items" => [%{"height" => 1}]}} =
             Client.get_json_uncached("/api/v2/blocks?limit=1")

    assert calls(agent, url) == 2
  end

  test "get_json_uncached/1 retries once on 429 then succeeds", %{stub_agent: agent} do
    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 429, body: "rate limited"}},
      {:ok, %Req.Response{status: 200, body: ~s({"ok":true})}}
    ])

    assert {:ok, %{"ok" => true}} = Client.get_json_uncached("/api/v2/stats")
    assert calls(agent, url) == 2
  end

  test "get_json_uncached/1 treats invalid JSON as :not_found after retries", %{stub_agent: agent} do
    url = "http://stub/api/v2/bad-json"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 200, body: "{"}},
      {:ok, %Req.Response{status: 200, body: "{"}},
      {:ok, %Req.Response{status: 200, body: "{"}}
    ])

    assert {:error, :not_found} = Client.get_json_uncached("/api/v2/bad-json")
    assert calls(agent, url) == 3
  end

  test "get_json_uncached/1 rejects paths that produce invalid URLs", %{stub_agent: _agent} do
    assert {:error, {:transport, :invalid_url}} = Client.get_json_uncached("/api/v2/blocks?x= y")
  end

  test "get_json_cached/2 caches successful responses for the TTL", %{stub_agent: agent} do
    FrontendEx.Cache.clear(FrontendEx.ApiCache)

    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 200, body: ~s({"ok":true})}}
    ])

    assert {:ok, %{"ok" => true}} = Client.get_json_cached("/api/v2/stats", :public)
    assert {:ok, %{"ok" => true}} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 1
  end

  test "get_json_cached/2 negative-caches :not_found (404) for ~5s", %{stub_agent: agent} do
    FrontendEx.Cache.clear(FrontendEx.ApiCache)

    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 404, body: "not found"}},
      {:ok, %Req.Response{status: 200, body: ~s({"ok":true})}}
    ])

    assert {:error, :not_found} = Client.get_json_cached("/api/v2/stats", :public)
    assert {:error, :not_found} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 1
  end

  test "get_json_cached/2 does not cache non-:not_found upstream errors", %{stub_agent: agent} do
    FrontendEx.Cache.clear(FrontendEx.ApiCache)

    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 400, body: "bad request"}},
      {:ok, %Req.Response{status: 200, body: ~s({"ok":true})}}
    ])

    assert {:error, {:http_status, 400, _}} = Client.get_json_cached("/api/v2/stats", :public)
    assert {:ok, %{"ok" => true}} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 2
  end

  test "get_json_cached/2 refetches after the positive TTL expires (deterministic clock)", %{
    stub_agent: agent
  } do
    clock = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: make_ref()))
    now_ms = fn -> Agent.get(clock, & &1) end

    cache_name = Module.concat(__MODULE__, ApiCache)
    start_supervised!({FrontendEx.Cache, name: cache_name, now_ms: now_ms, max_entries: 100})

    old_cache_server = Application.fetch_env(:frontend_ex, :blockscout_api_cache_server)
    Application.put_env(:frontend_ex, :blockscout_api_cache_server, cache_name)

    on_exit(fn ->
      case old_cache_server do
        {:ok, value} -> Application.put_env(:frontend_ex, :blockscout_api_cache_server, value)
        :error -> Application.delete_env(:frontend_ex, :blockscout_api_cache_server)
      end
    end)

    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 200, body: ~s({"v":1})}},
      {:ok, %Req.Response{status: 200, body: ~s({"v":2})}}
    ])

    assert {:ok, %{"v" => 1}} = Client.get_json_cached("/api/v2/stats", :public)
    assert {:ok, %{"v" => 1}} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 1

    Agent.update(clock, fn _ -> 60_001 end)
    assert {:ok, %{"v" => 2}} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 2
  end

  test "get_json_cached/2 refetches after the negative TTL expires (deterministic clock)", %{
    stub_agent: agent
  } do
    clock = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: make_ref()))
    now_ms = fn -> Agent.get(clock, & &1) end

    cache_name = Module.concat(__MODULE__, ApiCache)
    start_supervised!({FrontendEx.Cache, name: cache_name, now_ms: now_ms, max_entries: 100})

    old_cache_server = Application.fetch_env(:frontend_ex, :blockscout_api_cache_server)
    Application.put_env(:frontend_ex, :blockscout_api_cache_server, cache_name)

    on_exit(fn ->
      case old_cache_server do
        {:ok, value} -> Application.put_env(:frontend_ex, :blockscout_api_cache_server, value)
        :error -> Application.delete_env(:frontend_ex, :blockscout_api_cache_server)
      end
    end)

    url = "http://stub/api/v2/stats"

    put_script(agent, url, [
      {:ok, %Req.Response{status: 404, body: "not found"}},
      {:ok, %Req.Response{status: 200, body: ~s({"ok":true})}}
    ])

    assert {:error, :not_found} = Client.get_json_cached("/api/v2/stats", :public)
    assert {:error, :not_found} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 1

    Agent.update(clock, fn _ -> 5_001 end)
    assert {:ok, %{"ok" => true}} = Client.get_json_cached("/api/v2/stats", :public)
    assert calls(agent, url) == 2
  end
end
