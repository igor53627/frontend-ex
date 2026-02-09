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
end
