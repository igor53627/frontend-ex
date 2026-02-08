defmodule FrontendExWeb.Plugs.FastLayout do
  @moduledoc false

  import Phoenix.Controller, only: [put_root_layout: 2]

  def init(opts), do: opts

  def call(conn, _opts) do
    layout =
      case FrontendExWeb.Skin.current() do
        :classic -> {FrontendExWeb.FastLayouts, :classic}
        :s53627 -> {FrontendExWeb.FastLayouts, :s53627}
      end

    put_root_layout(conn, html: layout)
  end
end
