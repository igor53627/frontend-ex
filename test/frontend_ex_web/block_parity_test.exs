defmodule FrontendExWeb.BlockParityTest do
  # Parity tests mutate global Application env (skin, URLs), so they must be serial.
  use FrontendExWeb.ConnCase, async: false

  alias FrontendEx.TestSupport.Golden

  @golden_block_classic_path Path.expand("../golden/block.classic.rust.html", __DIR__)
  @golden_block_53627_path Path.expand("../golden/block.53627.rust.html", __DIR__)
  @golden_txs_classic_path Path.expand("../golden/block_txs.classic.rust.html", __DIR__)
  @golden_txs_53627_path Path.expand("../golden/block_txs.53627.rust.html", __DIR__)

  @block_id "7000000"

  # Rust goldens were generated from API fixtures whose timestamps are in late 2025.
  # Freeze "now" so relative time strings stay stable.
  @frozen_now ~U[2026-02-01 00:00:00Z]
  @fixture_api_url "http://127.0.0.1:4901"
  @explorer_url "https://sepolia.53627.org"

  test "classic /block/:id matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/block/#{@block_id}"), 200)

    Golden.assert_golden!(@golden_block_classic_path, body)
  end

  test "classic /block/:id/txs matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/block/#{@block_id}/txs"), 200)

    Golden.assert_golden!(@golden_txs_classic_path, body)
  end

  test "53627 /block/:id matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/block/#{@block_id}"), 200)

    Golden.assert_golden!(@golden_block_53627_path, body)
  end

  test "53627 /block/:id/txs matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/block/#{@block_id}/txs"), 200)

    Golden.assert_golden!(@golden_txs_53627_path, body)
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

