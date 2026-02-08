defmodule FrontendExWeb.Plugs.TrimTrailingNewline do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      body =
        case conn.resp_body do
          body when is_binary(body) -> body
          body when is_list(body) -> IO.iodata_to_binary(body)
          _ -> nil
        end

      if is_binary(body) do
        %{conn | resp_body: String.trim_trailing(body, "\n")}
      else
        conn
      end
    end)
  end
end
