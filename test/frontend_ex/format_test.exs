defmodule FrontendEx.FormatTest do
  use ExUnit.Case, async: true

  alias FrontendEx.Format

  test "checksum_eth_address returns EIP-55 checksum" do
    assert Format.checksum_eth_address("0x52908400098527886e0f7030069857d2e4169ee7") ==
             "0x52908400098527886E0F7030069857D2E4169EE7"

    assert Format.checksum_eth_address("0x8617e340b3d01fa5f11f306f4090fd50e238070d") ==
             "0x8617E340B3D01FA5F11F306F4090FD50E238070D"
  end

  test "format_method_name humanizes non-hex method names" do
    assert Format.format_method_name("") == "-"
    assert Format.format_method_name("  ") == "-"
    assert Format.format_method_name("0x1234") == "0x1234"
    assert Format.format_method_name("swapExactTokensForETH") == "Swap Exact Tokens For ETH"
    assert Format.format_method_name("permit2") == "Permit 2"
    assert Format.format_method_name("some_method-name") == "Some Method Name"
  end

  test "format_one_decimal/1 formats integers and rounds floats" do
    assert Format.format_one_decimal(1) == "1.0"
    assert Format.format_one_decimal(-1) == "-1.0"
    assert Format.format_one_decimal(1.04) == "1.0"
    assert Format.format_one_decimal(1.05) == "1.1"
  end

  describe "format_blocks_time_ago/1" do
    setup do
      frozen_now = ~U[2026-02-09 12:00:00Z]

      old = Application.get_env(:frontend_ex, :clock_utc_now)
      Application.put_env(:frontend_ex, :clock_utc_now, frozen_now)

      on_exit(fn ->
        if is_nil(old) do
          Application.delete_env(:frontend_ex, :clock_utc_now)
        else
          Application.put_env(:frontend_ex, :clock_utc_now, old)
        end
      end)

      %{now: frozen_now}
    end

    test "covers secs/mins/hrs/days boundaries", %{now: now} do
      assert Format.format_blocks_time_ago(
               DateTime.add(now, -59, :second)
               |> DateTime.to_iso8601()
             ) ==
               "59 secs ago"

      assert Format.format_blocks_time_ago(
               DateTime.add(now, -60, :second)
               |> DateTime.to_iso8601()
             ) ==
               "1 mins ago"

      assert Format.format_blocks_time_ago(
               DateTime.add(now, -3599, :second)
               |> DateTime.to_iso8601()
             ) ==
               "59 mins ago"

      assert Format.format_blocks_time_ago(
               DateTime.add(now, -3600, :second)
               |> DateTime.to_iso8601()
             ) ==
               "1 hrs ago"

      assert Format.format_blocks_time_ago(
               DateTime.add(now, -86399, :second)
               |> DateTime.to_iso8601()
             ) ==
               "23 hrs ago"

      assert Format.format_blocks_time_ago(
               DateTime.add(now, -86400, :second)
               |> DateTime.to_iso8601()
             ) ==
               "1 days ago"
    end

    test "clamps future timestamps to 0 secs ago", %{now: now} do
      assert Format.format_blocks_time_ago(
               DateTime.add(now, 10, :second)
               |> DateTime.to_iso8601()
             ) ==
               "0 secs ago"
    end

    test "returns input on parse failure" do
      assert Format.format_blocks_time_ago("not-a-timestamp") == "not-a-timestamp"
    end
  end
end
