defmodule FrontendExWeb.TokenParityTest do
  # Parity tests mutate global Application env (skin, URLs), so they must be serial.
  use FrontendExWeb.ConnCase, async: false

  alias FrontendEx.TestSupport.Golden

  @golden_classic_path Path.expand("../golden/token.classic.rust.html", __DIR__)
  @golden_classic_holders_path Path.expand(
                                   "../golden/token_holders.classic.rust.html",
                                   __DIR__
                                 )
  @golden_53627_path Path.expand("../golden/token.53627.rust.html", __DIR__)
  @golden_53627_holders_path Path.expand("../golden/token_holders.53627.rust.html", __DIR__)

  @token_address "0x54fa517f05e11ffa87f4b22ae87d91cec0c2d7e1"

  @frozen_now ~U[2026-02-09 12:00:00Z]
  @fixture_api_url "http://127.0.0.1:4901"
  @explorer_url "https://sepolia.53627.org"

  test "classic /token/:address matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/token/#{@token_address}"), 200)

    Golden.assert_golden!(@golden_classic_path, body)
  end

  test "classic /token/:address/holders matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/token/#{@token_address}/holders"), 200)

    Golden.assert_golden!(@golden_classic_holders_path, body)
  end

  test "53627 /token/:address matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/token/#{@token_address}"), 200)

    Golden.assert_golden!(@golden_53627_path, body)
  end

  test "53627 /token/:address/holders matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/token/#{@token_address}/holders"), 200)

    Golden.assert_golden!(@golden_53627_holders_path, body)
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
