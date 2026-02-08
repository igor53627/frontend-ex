defmodule FrontendEx.Blockscout.ClientTest do
  use ExUnit.Case

  alias FrontendEx.Blockscout.Client

  setup do
    bypass = Bypass.open()

    old_api_url = Application.get_env(:frontend_ex, :blockscout_api_url)
    Application.put_env(:frontend_ex, :blockscout_api_url, "http://localhost:#{bypass.port}/")

    on_exit(fn ->
      Application.put_env(:frontend_ex, :blockscout_api_url, old_api_url)
    end)

    {:ok, bypass: bypass}
  end

  test "get_json/1 fetches and decodes JSON (stats endpoint)", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v2/stats", fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, ~s({"ok":true}))
    end)

    assert {:ok, %{"ok" => true}} = Client.get_json("api/v2/stats")
  end

  test "get_json/1 maps 404 to :not_found (tx endpoint)", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/api/v2/transactions/0xdead", fn conn ->
      Plug.Conn.resp(conn, 404, "not found")
    end)

    assert {:error, :not_found} = Client.get_json("/api/v2/transactions/0xdead")
  end

  test "get_json/1 retries once on 5xx then succeeds (blocks endpoint)", %{bypass: bypass} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Bypass.expect(bypass, "GET", "/api/v2/blocks", fn conn ->
      assert conn.query_string == "limit=1"

      n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      case n do
        0 ->
          Plug.Conn.resp(conn, 500, "upstream error")

        _ ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, ~s({"items":[{"height":1}]}))
      end
    end)

    assert {:ok, %{"items" => [%{"height" => 1}]}} = Client.get_json("/api/v2/blocks?limit=1")
    assert Agent.get(counter, & &1) == 2
  end

  test "get_json/1 retries once on 429 then succeeds", %{bypass: bypass} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Bypass.expect(bypass, "GET", "/api/v2/stats", fn conn ->
      n = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      case n do
        0 ->
          Plug.Conn.resp(conn, 429, "rate limited")

        _ ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, ~s({"ok":true}))
      end
    end)

    assert {:ok, %{"ok" => true}} = Client.get_json("/api/v2/stats")
    assert Agent.get(counter, & &1) == 2
  end

  test "get_json/1 treats invalid JSON as :not_found after retries", %{bypass: bypass} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    Bypass.expect(bypass, "GET", "/api/v2/bad-json", fn conn ->
      _ = Agent.get_and_update(counter, fn n -> {n, n + 1} end)

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.resp(200, "{")
    end)

    assert {:error, :not_found} = Client.get_json("/api/v2/bad-json")
    assert Agent.get(counter, & &1) == 3
  end

  test "get_json/1 rejects paths that produce invalid URLs", %{bypass: bypass} do
    _ = bypass
    assert {:error, {:transport, :invalid_url}} = Client.get_json("/api/v2/blocks?x= y")
  end
end
