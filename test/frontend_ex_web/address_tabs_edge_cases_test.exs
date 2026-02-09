defmodule FrontendExWeb.AddressTabsEdgeCasesTest do
  # Mutates global Application env (skin, URLs), so it must be serial.
  use FrontendExWeb.ConnCase, async: false

  @frozen_now ~U[2026-02-01 00:00:00Z]
  @fixture_api_url "http://127.0.0.1:4901"
  @explorer_url "https://sepolia.53627.org"

  @addr_blank_hash "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
  @addr_missing_ids "0xcccccccccccccccccccccccccccccccccccccccc"

  test "classic /address/:address/tokens returns 404 when upstream address hash is blank" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    conn = get(build_conn(), "/address/#{@addr_blank_hash}/tokens")

    assert response(conn, 404) == "Address not found"
  end

  test "classic /address/:address/token-transfers disables links/copy when ids are missing" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/address/#{@addr_missing_ids}/token-transfers"), 200)

    assert body =~ "href=\"#\""
    assert body =~ "data-copy=\"\""
    assert body =~ "aria-disabled=\"true\""
    assert body =~ "onclick=\"return false;\""

    refute body =~ "/tx/-"
    refute body =~ "/block/-"
    refute body =~ "/address/-"
  end

  test "classic /address/:address/internal disables links/copy when ids are missing" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/address/#{@addr_missing_ids}/internal"), 200)

    assert body =~ "href=\"#\""
    assert body =~ "data-copy=\"\""
    assert body =~ "aria-disabled=\"true\""
    assert body =~ "onclick=\"return false;\""

    refute body =~ "/tx/-"
    refute body =~ "/block/-"
    refute body =~ "/address/-"
  end

  defp put_env(kvs) when is_map(kvs) do
    prev =
      for {k, _v} <- kvs, into: %{} do
        {k, Application.get_env(:frontend_ex, k)}
      end

    Enum.each(kvs, fn
      {k, nil} -> Application.delete_env(:frontend_ex, k)
      {k, v} -> Application.put_env(:frontend_ex, k, v)
    end)

    fn ->
      Enum.each(prev, fn
        {k, nil} -> Application.delete_env(:frontend_ex, k)
        {k, v} -> Application.put_env(:frontend_ex, k, v)
      end)
    end
  end
end
