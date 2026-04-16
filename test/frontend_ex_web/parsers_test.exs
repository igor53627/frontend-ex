defmodule FrontendExWeb.ParsersTest do
  use ExUnit.Case, async: true

  alias FrontendExWeb.Parsers

  describe "eth_address?/1" do
    test "accepts lowercase, uppercase, and mixed-case hex" do
      assert Parsers.eth_address?("0x" <> String.duplicate("a", 40))
      assert Parsers.eth_address?("0x" <> String.duplicate("A", 40))
      assert Parsers.eth_address?("0xAaBbCcDdEeFf0011223344556677889900aAbBcC")
    end

    test "accepts uppercase 0X prefix" do
      assert Parsers.eth_address?("0X" <> String.duplicate("a", 40))
    end

    test "rejects wrong length" do
      refute Parsers.eth_address?("0x" <> String.duplicate("a", 39))
      refute Parsers.eth_address?("0x" <> String.duplicate("a", 41))
    end

    test "rejects missing 0x prefix" do
      refute Parsers.eth_address?(String.duplicate("a", 40))
    end

    test "rejects non-hex characters" do
      refute Parsers.eth_address?("0x" <> String.duplicate("g", 40))
    end

    test "rejects leading/trailing whitespace" do
      refute Parsers.eth_address?("  0x" <> String.duplicate("a", 40) <> "  ")
    end

    test "rejects non-binary input" do
      refute Parsers.eth_address?(nil)
      refute Parsers.eth_address?(42)
      refute Parsers.eth_address?(:atom)
    end
  end

  describe "tx_hash?/1" do
    test "accepts 0x + 64 hex chars, any case" do
      assert Parsers.tx_hash?("0x" <> String.duplicate("a", 64))
      assert Parsers.tx_hash?("0x" <> String.duplicate("F", 64))
    end

    test "accepts uppercase 0X prefix" do
      assert Parsers.tx_hash?("0X" <> String.duplicate("a", 64))
    end

    test "rejects wrong length" do
      refute Parsers.tx_hash?("0x" <> String.duplicate("a", 63))
      refute Parsers.tx_hash?("0x" <> String.duplicate("a", 65))
    end

    test "rejects non-binary input" do
      refute Parsers.tx_hash?(nil)
    end
  end

  describe "block_id?/1" do
    test "accepts positive decimal strings" do
      assert Parsers.block_id?("0")
      assert Parsers.block_id?("123456")
    end

    test "accepts 32-byte hash" do
      assert Parsers.block_id?("0x" <> String.duplicate("a", 64))
    end

    test "accepts uppercase 0X prefix on hash" do
      assert Parsers.block_id?("0X" <> String.duplicate("a", 64))
    end

    test "rejects eth-address-sized hash" do
      refute Parsers.block_id?("0x" <> String.duplicate("a", 40))
    end

    test "rejects negative/signed/float/empty" do
      refute Parsers.block_id?("-1")
      refute Parsers.block_id?("1.5")
      refute Parsers.block_id?("")
    end

    test "rejects non-binary input" do
      refute Parsers.block_id?(123)
      refute Parsers.block_id?(nil)
    end
  end

  describe "parse_u64/1" do
    test "passes through non-negative integers" do
      assert Parsers.parse_u64(0) == 0
      assert Parsers.parse_u64(42) == 42
    end

    test "rejects negative integers" do
      assert Parsers.parse_u64(-1) == nil
    end

    test "parses positive decimal binary" do
      assert Parsers.parse_u64("0") == 0
      assert Parsers.parse_u64("42") == 42
    end

    test "trims whitespace" do
      assert Parsers.parse_u64("  42  ") == 42
    end

    test "returns nil for negative binary" do
      assert Parsers.parse_u64("-1") == nil
    end

    test "returns nil for non-integer binary" do
      assert Parsers.parse_u64("abc") == nil
      assert Parsers.parse_u64("42abc") == nil
      assert Parsers.parse_u64("") == nil
    end

    test "returns nil for unknown shapes" do
      assert Parsers.parse_u64(nil) == nil
      assert Parsers.parse_u64(1.5) == nil
      assert Parsers.parse_u64(%{}) == nil
    end
  end

  describe "parse_int_or/2" do
    test "returns fallback for nil" do
      assert Parsers.parse_int_or(nil, 99) == 99
    end

    test "returns integer passthrough" do
      assert Parsers.parse_int_or(42, -1) == 42
      assert Parsers.parse_int_or(-5, -1) == -5
    end

    test "parses binary (trimmed) with fallback" do
      assert Parsers.parse_int_or("10", 0) == 10
      assert Parsers.parse_int_or(" -7 ", 0) == -7
      assert Parsers.parse_int_or("nope", 99) == 99
    end

    test "returns fallback for unknown shapes" do
      assert Parsers.parse_int_or(1.5, "fb") == "fb"
      assert Parsers.parse_int_or(%{}, :fb) == :fb
    end
  end

  describe "normalize_opt_string/1" do
    test "trims binaries" do
      assert Parsers.normalize_opt_string("  hi  ") == "hi"
      assert Parsers.normalize_opt_string("") == ""
    end

    test "returns nil for non-binaries" do
      assert Parsers.normalize_opt_string(nil) == nil
      assert Parsers.normalize_opt_string(42) == nil
      assert Parsers.normalize_opt_string(:atom) == nil
    end
  end

  describe "regex accessors" do
    test "address_regex/0 returns a Regex" do
      assert %Regex{} = Parsers.address_regex()
    end

    test "hash32_regex/0 returns a Regex" do
      assert %Regex{} = Parsers.hash32_regex()
    end
  end
end
