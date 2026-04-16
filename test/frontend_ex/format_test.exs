defmodule FrontendEx.FormatTest do
  # Mutates global Application env (:clock_utc_now) for deterministic time formatting,
  # so it must not run concurrently with other tests that also depend on the clock.
  use ExUnit.Case, async: false

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

  describe "format_number_with_commas/1" do
    test "single digit passes through" do
      assert Format.format_number_with_commas("0") == "0"
      assert Format.format_number_with_commas("5") == "5"
    end

    test "2-3 digits pass through unchanged" do
      assert Format.format_number_with_commas("12") == "12"
      assert Format.format_number_with_commas("999") == "999"
    end

    test "4-6 digits: single comma" do
      assert Format.format_number_with_commas("1000") == "1,000"
      assert Format.format_number_with_commas("12345") == "12,345"
      assert Format.format_number_with_commas("123456") == "123,456"
    end

    test "7+ digits: multiple commas" do
      assert Format.format_number_with_commas("1234567") == "1,234,567"
      assert Format.format_number_with_commas("12345678") == "12,345,678"
      assert Format.format_number_with_commas("123456789") == "123,456,789"
      assert Format.format_number_with_commas("1000000000") == "1,000,000,000"
    end

    test "boundary: exactly 3 digits after first chunk" do
      # size = 6, head_size = 0 → treated as 3, then one chunk of 3
      assert Format.format_number_with_commas("999999") == "999,999"
    end

    test "very large integer (50+ digits)" do
      s = String.duplicate("1", 50)
      result = Format.format_number_with_commas(s)
      # Expect 16 commas: 50 digits = 1 head of 2 + 16 chunks of 3
      assert String.length(result) == 50 + 16
      # Verify round-trip: strip commas and compare to input
      assert String.replace(result, ",", "") == s
    end

    test "trims whitespace before parsing" do
      assert Format.format_number_with_commas("  1234  ") == "1,234"
    end

    test "passes unparseable input through verbatim" do
      assert Format.format_number_with_commas("abc") == "abc"
      assert Format.format_number_with_commas("") == ""
      assert Format.format_number_with_commas("1.5") == "1.5"
    end

    test "rejects negative" do
      # Negative is unparseable by the guard (n >= 0); returns trimmed input
      assert Format.format_number_with_commas("-1") == "-1"
    end
  end

  describe "format_decimal_with_commas/1 — UTF-8 safety" do
    test "ASCII int parts are formatted normally" do
      assert Format.format_decimal_with_commas("1234567.89") == "1,234,567.89"
      assert Format.format_decimal_with_commas("1000.5") == "1,000.5"
      assert Format.format_decimal_with_commas("1234") == "1,234"
    end

    test "non-ASCII int part is passed through without splitting codepoints" do
      # If upstream ever returns garbage, the formatter must not split
      # multi-byte UTF-8 sequences. Passing the non-numeric int part
      # through untouched is the safe outcome.
      assert Format.format_decimal_with_commas("нет.5") == "нет.5"
      assert Format.format_decimal_with_commas("ábcdé.5") == "ábcdé.5"
    end

    test "non-ASCII no-decimal input is passed through" do
      assert Format.format_decimal_with_commas("нет") == "нет"
    end
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
