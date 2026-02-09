defmodule FrontendExWeb.AddressParityTest do
  # Parity tests mutate global Application env (skin, URLs), so they must be serial.
  use FrontendExWeb.ConnCase, async: false

  alias FrontendEx.TestSupport.Golden

  @address "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  @golden_classic_path Path.expand("../golden/address.classic.rust.html", __DIR__)
  @golden_53627_path Path.expand("../golden/address.53627.rust.html", __DIR__)

  @frozen_now ~U[2026-02-01 00:00:00Z]
  @fixture_api_url "http://127.0.0.1:4901"
  @explorer_url "https://sepolia.53627.org"

  test "classic /address/:address matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/address/#{@address}"), 200)

    Golden.assert_golden!(@golden_classic_path, body)
  end

  test "53627 /address/:address matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/address/#{@address}"), 200)

    Golden.assert_golden!(@golden_53627_path, body)
  end

  test "not found returns 404 with Rust body" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now,
        blockscout_fixture_on_missing: :not_found
      })

    on_exit(restore)

    body = response(get(build_conn(), "/address/0xdeadbeef"), 404)
    assert body == "Address not found"
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

