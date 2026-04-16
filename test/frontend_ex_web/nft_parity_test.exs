defmodule FrontendExWeb.NftParityTest do
  # Parity tests mutate global Application env (skin, URLs), so they must be serial.
  use FrontendExWeb.ConnCase, async: false

  alias FrontendEx.TestSupport.Golden

  @golden_transfers_classic Path.expand("../golden/nft_transfers.classic.rust.html", __DIR__)
  @golden_latest_mints_classic Path.expand(
                                 "../golden/nft_latest_mints.classic.rust.html",
                                 __DIR__
                               )
  @golden_transfers_53627 Path.expand("../golden/nft_transfers.53627.rust.html", __DIR__)
  @golden_latest_mints_53627 Path.expand("../golden/nft_latest_mints.53627.rust.html", __DIR__)
  @golden_latest_mints_csv Path.expand("../golden/nft_latest_mints_export.rust.csv", __DIR__)

  @frozen_now ~U[2026-02-01 00:00:00Z]
  @fixture_api_url "http://127.0.0.1:4901"
  @explorer_url "https://sepolia.53627.org"

  test "classic /nft-transfers matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/nft-transfers"), 200)

    Golden.assert_golden!(@golden_transfers_classic, body)
  end

  test "classic /nft-latest-mints matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/nft-latest-mints"), 200)

    Golden.assert_golden!(@golden_latest_mints_classic, body)
  end

  test "53627 /nft-transfers matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/nft-transfers"), 200)

    Golden.assert_golden!(@golden_transfers_53627, body)
  end

  test "53627 /nft-latest-mints matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/nft-latest-mints"), 200)

    Golden.assert_golden!(@golden_latest_mints_53627, body)
  end

  test "/nft-latest-mints.csv matches Rust CSV byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    conn = get(build_conn(), "/nft-latest-mints.csv?mode=block")
    body = response(conn, 200)

    Golden.assert_golden!(@golden_latest_mints_csv, body)
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
