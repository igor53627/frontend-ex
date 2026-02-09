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
end
