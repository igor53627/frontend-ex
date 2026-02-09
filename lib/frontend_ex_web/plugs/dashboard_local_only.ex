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

  defp loopback_ip?({127, 0, 0, 1}), do: true
  defp loopback_ip?({0, 0, 0, 0, 0, 0, 0, 1}), do: true
  defp loopback_ip?(_), do: false
end
