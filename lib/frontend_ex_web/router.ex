defmodule FrontendExWeb.Router do
  use FrontendExWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {FrontendExWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Fast-frontend parity routes: SSR HTML with skin-specific root layouts.
  #
  # Intentionally does not include sessions/CSRF protection to avoid extra
  # HTML/meta tags and keep output byte-for-byte compatible with Rust.
  pipeline :fast_browser do
    plug :accepts, ["html"]
    plug FrontendExWeb.Plugs.FastLayout
    plug :put_layout, false
    plug :put_secure_browser_headers
    plug FrontendExWeb.Plugs.TrimTrailingNewline
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", FrontendExWeb do
    pipe_through :fast_browser

    get "/", HomeController, :index
    get "/block/:id", BlockController, :show
    get "/block/:id/txs", BlockController, :txs
    get "/tx/:hash", TxController, :show
    get "/address/:address", AddressController, :show
    get "/exportData", ExportDataController, :index
  end

  scope "/", FrontendExWeb do
    pipe_through :browser
  end

  # Other scopes may use custom stacks.
  # scope "/api", FrontendExWeb do
  #   pipe_through :api
  # end
end
