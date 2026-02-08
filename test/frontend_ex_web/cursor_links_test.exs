defmodule FrontendExWeb.CursorLinksTest do
  use ExUnit.Case

  alias FrontendExWeb.CursorLinks

  test "with_cursor/3 builds deterministic query string without double-encoding cursor" do
    cursor = "items_count%3D50%26block_number%3D1%26index%3D2"
    assert CursorLinks.with_cursor("/txs", cursor, [{"ps", 50}]) == "/txs?cursor=#{cursor}&ps=50"
  end

  test "without_cursor/2 drops cursor entirely (first page link)" do
    assert CursorLinks.without_cursor("/txs", []) == "/txs"
    assert CursorLinks.without_cursor("/txs", [{"ps", 25}]) == "/txs?ps=25"
  end
end
