defmodule FrontendExWeb.CursorLinksTest do
  use ExUnit.Case

  alias FrontendExWeb.CursorLinks

  test "with_cursor/3 encodes cursor and builds deterministic query string" do
    cursor = "items_count=50&block_number=1&index=2"
    expected_cursor = "items_count%3D50%26block_number%3D1%26index%3D2"

    assert CursorLinks.with_cursor("/txs", cursor, [{"ps", 50}]) ==
             "/txs?cursor=#{expected_cursor}&ps=50"
  end

  test "without_cursor/2 drops cursor entirely (first page link)" do
    assert CursorLinks.without_cursor("/txs", []) == "/txs"
    assert CursorLinks.without_cursor("/txs", [{"ps", 25}]) == "/txs?ps=25"
  end

  test "with_cursor/3 preserves and overrides existing query params" do
    cursor = "items_count=50&block_number=1&index=2"
    expected_cursor = "items_count%3D50%26block_number%3D1%26index%3D2"

    assert CursorLinks.with_cursor("/txs?ps=25", cursor, [{"ps", 50}]) ==
             "/txs?cursor=#{expected_cursor}&ps=50"
  end

  test "without_cursor/2 removes cursor from a path that already includes it" do
    expected_cursor = "items_count%3D50%26block_number%3D1%26index%3D2"

    assert CursorLinks.without_cursor("/txs?cursor=#{expected_cursor}&ps=50", []) == "/txs?ps=50"
  end

  test "with_cursor/3 prevents query param injection via unencoded cursor" do
    # If caller passes a decoded cursor containing `&ps=999`, it must remain inside the cursor value.
    cursor = "x=y&ps=999"
    url = CursorLinks.with_cursor("/txs", cursor, [{"ps", 50}])

    assert String.contains?(url, "cursor=x%3Dy%26ps%3D999")
    refute String.contains?(url, "&ps=999")
    assert String.contains?(url, "&ps=50")
  end
end
