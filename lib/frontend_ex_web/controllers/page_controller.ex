defmodule FrontendExWeb.PageController do
  use FrontendExWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
