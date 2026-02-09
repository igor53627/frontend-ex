import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :frontend_ex, FrontendExWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "4sKqK+UKftQQ3Zxl0VxgXg5PycuuB7MhHRyZBP09y96P4OYwp+0v4I1HUngwLv04",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# Tests must not perform real network calls. Blockscout API requests are served
# from on-disk fixtures via a pluggable request adapter.
config :frontend_ex,
  blockscout_request_adapter: FrontendEx.Blockscout.RequestAdapter.Fixture,
  blockscout_fixture_dir: Path.expand("../test/fixtures/blockscout", __DIR__),
  blockscout_fixture_on_missing: :raise

# Do not open a metrics server in tests (avoids port conflicts in parallel runs).
config :frontend_ex, :metrics, enabled: false
