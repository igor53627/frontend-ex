defmodule FrontendEx.Blockscout.CursorTest do
  use ExUnit.Case

  alias FrontendEx.Blockscout.Cursor

  test "next_page_params_query/1 preserves order for ordered objects" do
    params =
      Jason.OrderedObject.new([
        {"items_count", 50},
        {"block_number", 10_217_968},
        {"index", 82}
      ])

    assert Cursor.next_page_params_query(params) ==
             "items_count=50&block_number=10217968&index=82"
  end

  test "encode_next_page_params/1 percent-encodes full cursor query string" do
    params =
      Jason.OrderedObject.new([
        {"items_count", 50},
        {"block_number", 10_217_968},
        {"index", 82}
      ])

    assert Cursor.encode_next_page_params(params) ==
             "items_count%3D50%26block_number%3D10217968%26index%3D82"
  end

  test "encode/decode round-trip keeps inner value encoding (no double-decode)" do
    params =
      Jason.OrderedObject.new([
        {"type", "ERC-721,ERC-1155"},
        {"items_count", 50}
      ])

    cursor = Cursor.encode_next_page_params(params)
    assert cursor == "type%3DERC-721%252CERC-1155%26items_count%3D50"

    assert {:ok, decoded} = Cursor.decode_cursor_value(cursor)
    assert decoded == "type=ERC-721%2CERC-1155&items_count=50"
  end
end
