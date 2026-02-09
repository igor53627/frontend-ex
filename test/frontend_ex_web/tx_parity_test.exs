defmodule FrontendExWeb.TxParityTest do
  # Parity tests mutate global Application env (skin, URLs), so they must be serial.
  use FrontendExWeb.ConnCase, async: false

  alias FrontendEx.TestSupport.Golden

  @success_hash "0xa4e0caea19db95858a73899bf85cb9db999c97dd840a2472ae92d311b84b4126"
  @pending_hash "0x1111111111111111111111111111111111111111111111111111111111111111"
  @failed_hash "0x2222222222222222222222222222222222222222222222222222222222222222"

  @golden_classic_path Path.expand("../golden/tx.classic.rust.html", __DIR__)
  @golden_pending_classic_path Path.expand("../golden/tx_pending.classic.rust.html", __DIR__)
  @golden_failed_classic_path Path.expand("../golden/tx_failed.classic.rust.html", __DIR__)
  @golden_53627_path Path.expand("../golden/tx.53627.rust.html", __DIR__)
  @golden_pending_53627_path Path.expand("../golden/tx_pending.53627.rust.html", __DIR__)
  @golden_failed_53627_path Path.expand("../golden/tx_failed.53627.rust.html", __DIR__)

  # Rust goldens were generated from API fixtures whose timestamps are in late 2025.
  # Freeze "now" so relative time strings stay stable.
  @frozen_now ~U[2026-02-01 00:00:00Z]
  @fixture_api_url "http://127.0.0.1:4901"
  @explorer_url "https://sepolia.53627.org"
  @base_url "https://fast.53627.org"

  test "classic /tx/:hash matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/tx/#{@success_hash}"), 200)

    Golden.assert_golden!(@golden_classic_path, body)
  end

  test "classic pending /tx/:hash matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/tx/#{@pending_hash}"), 200)

    Golden.assert_golden!(@golden_pending_classic_path, body)
  end

  test "classic failed /tx/:hash matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/tx/#{@failed_hash}"), 200)

    Golden.assert_golden!(@golden_failed_classic_path, body)
  end

  test "53627 /tx/:hash matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/tx/#{@success_hash}"), 200)

    Golden.assert_golden!(@golden_53627_path, body)
  end

  test "53627 pending /tx/:hash matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/tx/#{@pending_hash}"), 200)

    Golden.assert_golden!(@golden_pending_53627_path, body)
  end

  test "53627 failed /tx/:hash matches Rust HTML byte-for-byte" do
    restore =
      put_env(%{
        ff_skin: "53627",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now
      })

    on_exit(restore)

    body = html_response(get(build_conn(), "/tx/#{@failed_hash}"), 200)

    Golden.assert_golden!(@golden_failed_53627_path, body)
  end

  test "not found returns 404 with Rust body" do
    restore =
      put_env(%{
        ff_skin: "classic",
        blockscout_url: @explorer_url,
        blockscout_api_url: @fixture_api_url,
        blockscout_ws_url: nil,
        base_url: @base_url,
        clock_utc_now: @frozen_now,
        blockscout_fixture_on_missing: :not_found
      })

    on_exit(restore)

    body = response(get(build_conn(), "/tx/0xdeadbeef"), 404)
    assert body == "Transaction not found"
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
