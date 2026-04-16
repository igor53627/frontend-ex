import Config

# Build-time secrets for prod releases. These must be available in the
# environment when `mix release` runs.
#
# Session options are compile-time in Phoenix — runtime.exs cannot change
# them after compilation — so we resolve them here.
session_signing_salt =
  System.get_env("SESSION_SIGNING_SALT") ||
    raise """
    environment variable SESSION_SIGNING_SALT is missing.
    Generate one with: mix phx.gen.secret 32
    """

live_view_signing_salt =
  System.get_env("LIVE_VIEW_SIGNING_SALT") ||
    raise """
    environment variable LIVE_VIEW_SIGNING_SALT is missing.
    Generate one with: mix phx.gen.secret 32
    """

config :frontend_ex, :session_signing_salt, session_signing_salt

config :frontend_ex, FrontendExWeb.Endpoint, live_view: [signing_salt: live_view_signing_salt]

# Force using SSL in production. This also sets the "strict-security-transport" header,
# known as HSTS. If you have a health check endpoint, you may want to exclude it below.
# Note `:force_ssl` is required to be set at compile-time.
config :frontend_ex, FrontendExWeb.Endpoint,
  force_ssl: [
    rewrite_on: [:x_forwarded_proto],
    exclude: ["localhost", "127.0.0.1"]
  ]

# Do not print debug messages in production
config :logger, level: :info

# Runtime production configuration, including reading
# of environment variables, is done on config/runtime.exs.
