defmodule FrontendEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FrontendExWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:frontend_ex, :dns_cluster_query) || :ignore},
      # Keep a single shared HTTP pool for all outbound requests.
      # Connect timeout is set to match fast-frontend's reqwest client (10s).
      {Finch, name: FrontendEx.Finch, pools: %{default: [conn_opts: [timeout: 10_000]]}},
      # In-memory caches for Blockscout API responses.
      {FrontendEx.Cache, name: FrontendEx.ApiCache, max_entries: 1000},
      {FrontendEx.Cache.SWR, name: FrontendEx.ApiSWRCache, max_entries: 100},
      {Phoenix.PubSub, name: FrontendEx.PubSub},
      # Start a worker by calling: FrontendEx.Worker.start_link(arg)
      # {FrontendEx.Worker, arg},
      # Start to serve requests, typically the last entry
      FrontendExWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: FrontendEx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FrontendExWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
