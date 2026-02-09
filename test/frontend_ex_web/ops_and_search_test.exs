defmodule FrontendExWeb.OpsAndSearchTest do
  use FrontendExWeb.ConnCase, async: true

  describe "GET /health" do
    test "returns 200 OK (text/plain)", %{conn: conn} do
      conn = get(conn, "/health")

      assert response(conn, 200) == "OK"

      [ct | _] = get_resp_header(conn, "content-type")
      assert String.starts_with?(ct, "text/plain")
    end
  end

  describe "GET /stats" do
    test "returns cache sizes and config as JSON", %{conn: conn} do
      conn = get(conn, "/stats")
      body = json_response(conn, 200)

      assert is_integer(body["cache_entries"])
      assert is_integer(body["swr_cache_entries"])

      assert %{
               "standard_ttl_secs" => 60,
               "negative_ttl_secs" => 5,
               "swr_fresh_secs" => 5,
               "swr_stale_secs" => 20
             } = body["cache_config"]

      assert %{"entries" => _} = body["api_cache"]
      assert %{"entries" => _} = body["swr_cache"]
    end
  end

  describe "GET /search" do
    test "empty q redirects to /", %{conn: conn} do
      conn = get(conn, "/search", %{"q" => ""})
      assert redirected_to(conn) == "/"
    end

    test "address-like query redirects to /address/:address", %{conn: conn} do
      addr = "0x" <> String.duplicate("a", 40)
      conn = get(conn, "/search", %{"q" => addr})
      assert redirected_to(conn) == "/address/#{addr}"
    end

    test "tx-like query redirects to /tx/:hash", %{conn: conn} do
      tx = "0x" <> String.duplicate("b", 64)
      conn = get(conn, "/search", %{"q" => tx})
      assert redirected_to(conn) == "/tx/#{tx}"
    end

    test "digits redirect to /block/:id", %{conn: conn} do
      conn = get(conn, "/search", %{"q" => "1024"})
      assert redirected_to(conn) == "/block/1024"
    end

    test "fallback redirects to upstream search", %{conn: conn} do
      prev = Application.get_env(:frontend_ex, :blockscout_url)

      Application.put_env(:frontend_ex, :blockscout_url, "https://blockscout.example")

      on_exit(fn ->
        if is_nil(prev) do
          Application.delete_env(:frontend_ex, :blockscout_url)
        else
          Application.put_env(:frontend_ex, :blockscout_url, prev)
        end
      end)

      conn = get(conn, "/search", %{"q" => "foo bar"})
      assert redirected_to(conn) == "https://blockscout.example/search?q=foo+bar"
    end
  end
end
