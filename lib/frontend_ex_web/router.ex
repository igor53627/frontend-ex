defmodule FrontendExWeb.Router do
  use FrontendExWeb, :router

  # Sessions/CSRF are intentionally avoided for parity SSR routes (see :fast_browser),
  # but we keep a working :browser pipeline for future non-parity pages.
  @session_options [
    store: :cookie,
    key: "_frontend_ex_key",
    signing_salt: "EF6QTIu+",
    same_site: "Lax"
  ]

  pipeline :browser do
    plug :accepts, ["html"]
    plug Plug.Session, @session_options
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
    # Ops/debug routes: no SSR pipeline, no trailing-newline trimming.
    get "/health", OpsController, :health
    get "/stats", OpsController, :stats
  end

  scope "/", FrontendExWeb do
    pipe_through :fast_browser

    get "/", HomeController, :index
    get "/search", SearchController, :index
    get "/blocks", BlocksController, :index
    get "/txs", TxsController, :index
    get "/tokens", TokensController, :index
    get "/block/:id", BlockController, :show
    get "/block/:id/txs", BlockController, :txs
    get "/tx/:hash", TxController, :show
    get "/tx/:hash/internal", TxController, :internal
    get "/tx/:hash/logs", TxController, :logs
    get "/tx/:hash/state", TxController, :state
    get "/tx/:hash/card", TxController, :card
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
