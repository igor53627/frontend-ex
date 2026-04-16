defmodule FrontendExWeb.Plugs.DashboardLocalOnly do
  @moduledoc false

  import Plug.Conn

  # In production, requests reach Phoenix through Caddy (reverse proxy).
  # We intentionally keep LiveDashboard reachable only via direct localhost access
  # (e.g. SSH port-forward to 127.0.0.1:5174) and return 404 for proxied requests.
  @forwarded_headers ["forwarded", "x-forwarded-for", "x-forwarded-host", "x-forwarded-proto"]

  def init(opts), do: opts

  def call(conn, _opts) do
    forwarded? = Enum.any?(@forwarded_headers, &(get_req_header(conn, &1) != []))

    if forwarded? or not loopback_ip?(conn.remote_ip) do
      conn
      |> send_resp(404, "Not found")
      |> halt()
    else
      conn
    end
  end

  # IPv4 loopback 127.0.0.1.
  defp loopback_ip?({127, 0, 0, 1}), do: true
  # IPv6 loopback ::1.
  defp loopback_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  # IPv4-mapped IPv6 ::ffff:127.0.0.1 — dual-stack sockets may present v4
  # loopback in this form. `0x7f00` is `127 <<< 8`; `0x0001` is the final byte.
  defp loopback_ip?({0, 0, 0, 0, 0, 0xFFFF, 0x7F00, 0x0001}), do: true
  defp loopback_ip?(_), do: false
end
