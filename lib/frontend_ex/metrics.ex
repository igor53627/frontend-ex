defmodule FrontendEx.Metrics do
  @moduledoc false

  # Periodic telemetry measurements for app-level metrics.
  #
  # IMPORTANT: These functions must never raise, otherwise telemetry_poller will
  # drop the measurement.

  def dispatch_cache_stats do
    api_cache =
      Application.get_env(:frontend_ex, :blockscout_api_cache_server, FrontendEx.ApiCache)

    swr_cache =
      Application.get_env(:frontend_ex, :blockscout_api_swr_cache_server, FrontendEx.ApiSWRCache)

    api_stats = FrontendEx.Cache.stats(api_cache)
    swr_stats = FrontendEx.Cache.SWR.stats(swr_cache)

    :telemetry.execute([:frontend_ex, :cache], %{
      api_entries: api_stats.entries,
      swr_entries: swr_stats.entries
    })

    :ok
  rescue
    _ -> :ok
  end
end
