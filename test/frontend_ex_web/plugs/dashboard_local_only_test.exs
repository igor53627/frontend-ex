defmodule FrontendExWeb.Plugs.DashboardLocalOnlyTest do
  use FrontendExWeb.ConnCase, async: true

  alias FrontendExWeb.Plugs.DashboardLocalOnly

  test "blocks requests that look proxied (forwarded headers)", %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> Plug.Conn.put_req_header("x-forwarded-for", "203.0.113.10")
      |> DashboardLocalOnly.call([])

    assert conn.halted
    assert response(conn, 404) == "Not found"
  end

  test "blocks non-loopback clients even without forwarded headers", %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, {203, 0, 113, 10})
      |> DashboardLocalOnly.call([])

    assert conn.halted
    assert response(conn, 404) == "Not found"
  end

  test "allows loopback without forwarded headers", %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, {127, 0, 0, 1})
      |> DashboardLocalOnly.call([])

    refute conn.halted
  end

  test "allows IPv6 ::1 loopback", %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, {0, 0, 0, 0, 0, 0, 0, 1})
      |> DashboardLocalOnly.call([])

    refute conn.halted
  end

  test "allows IPv4-mapped IPv6 ::ffff:127.0.0.1", %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, {0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001})
      |> DashboardLocalOnly.call([])

    refute conn.halted
  end

  test "rejects non-loopback IPv6 addresses", %{conn: conn} do
    conn =
      conn
      |> Map.put(:remote_ip, {0x2001, 0xDB8, 0, 0, 0, 0, 0, 1})
      |> DashboardLocalOnly.call([])

    assert conn.halted
    assert response(conn, 404) == "Not found"
  end
end
