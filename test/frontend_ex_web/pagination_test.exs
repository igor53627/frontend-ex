defmodule FrontendExWeb.PaginationTest do
  use ExUnit.Case, async: true

  alias FrontendExWeb.Pagination

  @options [10, 25, 50, 100]
  @default 50

  describe "normalize_page_size/3" do
    test "returns default when no size param present" do
      assert Pagination.normalize_page_size(%{}, @options, @default) == @default
    end

    test "reads `ps` in preference to `limit`" do
      assert Pagination.normalize_page_size(%{"ps" => "25", "limit" => "10"}, @options, @default) ==
               25
    end

    test "reads `limit` when `ps` missing" do
      assert Pagination.normalize_page_size(%{"limit" => "25"}, @options, @default) == 25
    end

    test "accepts integer values" do
      assert Pagination.normalize_page_size(%{"ps" => 100}, @options, @default) == 100
    end

    test "trims whitespace" do
      assert Pagination.normalize_page_size(%{"ps" => "  50  "}, @options, @default) == 50
    end

    test "falls back to default when value not in allowed list" do
      assert Pagination.normalize_page_size(%{"ps" => "42"}, @options, @default) == @default
    end

    test "falls back to default for non-numeric strings" do
      assert Pagination.normalize_page_size(%{"ps" => "abc"}, @options, @default) == @default
    end

    test "falls back to default for trailing garbage" do
      assert Pagination.normalize_page_size(%{"ps" => "50abc"}, @options, @default) == @default
    end

    test "falls back to default for unknown shapes" do
      assert Pagination.normalize_page_size(%{"ps" => nil}, @options, @default) == @default
      assert Pagination.normalize_page_size(%{"ps" => [1]}, @options, @default) == @default
    end
  end

  describe "normalize_cursor_param/1" do
    test "returns nil for nil" do
      assert Pagination.normalize_cursor_param(nil) == nil
    end

    test "returns trimmed binary" do
      assert Pagination.normalize_cursor_param("  abc  ") == "abc"
    end

    test "returns nil for empty/whitespace-only binaries" do
      assert Pagination.normalize_cursor_param("") == nil
      assert Pagination.normalize_cursor_param("   ") == nil
    end

    test "returns nil for non-binary input" do
      assert Pagination.normalize_cursor_param(42) == nil
      assert Pagination.normalize_cursor_param(:atom) == nil
    end
  end
end
