defmodule FrontendExWeb.Plugs.TrimTrailingNewlineTest do
  use FrontendExWeb.ConnCase, async: true

  alias FrontendExWeb.Plugs.TrimTrailingNewline

  defp send_trimmed(conn, body) do
    conn
    |> TrimTrailingNewline.call([])
    |> Plug.Conn.resp(200, body)
    |> Plug.Conn.send_resp()
  end

  test "trims trailing newlines from binary", %{conn: conn} do
    conn = send_trimmed(conn, "abc\n\n")
    assert response(conn, 200) == "abc"
  end

  test "trims trailing newlines from iodata binaries", %{conn: conn} do
    conn = send_trimmed(conn, ["a", "b", "\n"])
    assert response(conn, 200) == "ab"
  end

  test "trims trailing newlines from iodata integers (charlists)", %{conn: conn} do
    conn = send_trimmed(conn, ~c"ab\n\n")
    assert response(conn, 200) == "ab"
  end

  test "trims trailing newlines across nested iodata lists", %{conn: conn} do
    conn = send_trimmed(conn, ["a", ["b", "\n"], "\n"])
    assert response(conn, 200) == "ab"
  end

  test "does not trim non-trailing newlines", %{conn: conn} do
    conn = send_trimmed(conn, ["a", "\n", "b"])
    assert response(conn, 200) == "a\nb"
  end

  test "empty or newline-only bodies become empty", %{conn: conn} do
    conn = send_trimmed(conn, ["\n", "\n"])
    assert response(conn, 200) == ""
  end

  defp send_with_type(conn, body, content_type) do
    conn
    |> TrimTrailingNewline.call([])
    |> Plug.Conn.put_resp_content_type(content_type)
    |> Plug.Conn.resp(200, body)
    |> Plug.Conn.send_resp()
  end

  describe "content-type dispatch" do
    test "trims text/html responses", %{conn: conn} do
      conn = send_with_type(conn, "<html></html>\n\n", "text/html")
      assert response(conn, 200) == "<html></html>"
    end

    test "trims text/html; charset=utf-8 responses", %{conn: conn} do
      conn = send_with_type(conn, "<html></html>\n", "text/html; charset=utf-8")
      assert response(conn, 200) == "<html></html>"
    end

    test "does NOT trim text/csv responses (preserves parity newlines)", %{conn: conn} do
      conn = send_with_type(conn, "a,b,c\n1,2,3\n", "text/csv")
      assert response(conn, 200) == "a,b,c\n1,2,3\n"
    end

    test "does NOT trim image/svg+xml responses", %{conn: conn} do
      conn = send_with_type(conn, "<svg></svg>\n", "image/svg+xml")
      assert response(conn, 200) == "<svg></svg>\n"
    end

    test "does NOT trim application/json responses", %{conn: conn} do
      conn = send_with_type(conn, "{\"ok\":true}\n", "application/json")
      assert response(conn, 200) == "{\"ok\":true}\n"
    end

    test "does NOT trim text/plain responses", %{conn: conn} do
      conn = send_with_type(conn, "hello\n", "text/plain")
      assert response(conn, 200) == "hello\n"
    end
  end
end
