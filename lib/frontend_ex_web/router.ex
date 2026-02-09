defmodule FrontendExWeb.Router do
  use FrontendExWeb, :router

  import Phoenix.LiveDashboard.Router

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

  # CSV exports: parity routes, but allow `Accept: text/csv`.
  pipeline :fast_csv do
    plug :accepts, ["html", "csv"]
    plug FrontendExWeb.Plugs.FastLayout
    plug :put_layout, false
    plug :put_secure_browser_headers
    plug FrontendExWeb.Plugs.TrimTrailingNewline
  end

  # Standalone HTML documents (no root layout). Used for share cards that are
  # full HTML pages and should not be wrapped by the skin layout.
  pipeline :fast_plain_html do
    plug :accepts, ["html"]
    plug :put_root_layout, false
    plug :put_layout, false
    plug :put_secure_browser_headers
    plug FrontendExWeb.Plugs.TrimTrailingNewline
  end

  # Non-HTML assets (e.g. SVG) that should not be wrapped by the skin layout.
  pipeline :fast_svg do
    plug :accepts, ["html", "svg"]
    plug :put_root_layout, false
    plug :put_layout, false
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :dashboard do
    plug FrontendExWeb.Plugs.DashboardLocalOnly
  end

  scope "/", FrontendExWeb do
    # Ops/debug routes: no SSR pipeline, no trailing-newline trimming.
    get "/health", OpsController, :health
    get "/stats", OpsController, :stats
  end

  scope "/", FrontendExWeb do
    pipe_through [:browser, :dashboard]

    live_dashboard "/_dashboard", metrics: FrontendExWeb.Telemetry
  end

  scope "/", FrontendExWeb do
    pipe_through :fast_csv

    get "/nft-latest-mints.csv", NftController, :latest_mints_csv
  end

  scope "/", FrontendExWeb do
    pipe_through :fast_browser

    get "/", HomeController, :index
    get "/search", SearchController, :index
    get "/blocks", BlocksController, :index
    get "/txs", TxsController, :index
    get "/tokens", TokensController, :index
    get "/nft-transfers", NftController, :transfers
    get "/nft-latest-mints", NftController, :latest_mints
    get "/block/:id", BlockController, :show
    get "/block/:id/txs", BlockController, :txs
    get "/tx/:hash", TxController, :show
    get "/tx/:hash/internal", TxController, :internal
    get "/tx/:hash/logs", TxController, :logs
    get "/tx/:hash/state", TxController, :state
    get "/address/:address", AddressController, :show
    get "/address/:address/tokens", AddressTabsController, :tokens
    get "/address/:address/token-transfers", AddressTabsController, :token_transfers
    get "/address/:address/internal", AddressTabsController, :internal
    get "/token/:address", TokenController, :show
    get "/token/:address/holders", TokenController, :holders
    get "/exportData", ExportDataController, :index
  end

  scope "/", FrontendExWeb do
    pipe_through :fast_plain_html

    get "/tx/:hash/card", TxController, :card
  end

  scope "/", FrontendExWeb do
    pipe_through :fast_svg

    get "/tx/:hash/og-image.svg", TxController, :og_image
  end

  scope "/", FrontendExWeb do
    pipe_through :browser
  end

  # Other scopes may use custom stacks.
  # scope "/api", FrontendExWeb do
  #   pipe_through :api
  # end
end
