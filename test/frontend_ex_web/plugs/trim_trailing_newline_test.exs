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
end
