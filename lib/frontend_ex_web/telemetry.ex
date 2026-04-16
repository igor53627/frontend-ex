defmodule FrontendExWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
    ]

    children =
      if metrics_enabled?() do
        [
          {TelemetryMetricsPrometheus,
           metrics: metrics(),
           name: :frontend_ex_metrics,
           port: metrics_port(),
           plug_cowboy_opts: [ip: metrics_ip()]}
          | children
        ]
      else
        children
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix request metrics
      counter("phoenix.endpoint.stop.count.total",
        event_name: [:phoenix, :endpoint, :stop],
        measurement: &inc_one/2,
        description: "Total number of HTTP requests handled by the Phoenix endpoint."
      ),
      distribution("phoenix.endpoint.stop.duration.seconds",
        event_name: [:phoenix, :endpoint, :stop],
        measurement: :duration,
        unit: {:native, :second},
        reporter_options: [buckets: duration_buckets_seconds()],
        description: "Histogram of endpoint request duration."
      ),
      # `:route` is Phoenix's matched route *template* (e.g. "/block/:id"), not
      # the resolved path — so cardinality is bounded by route count, not
      # request count. Safe as a Prometheus label.
      counter("phoenix.router_dispatch.stop.count.total",
        event_name: [:phoenix, :router_dispatch, :stop],
        measurement: &inc_one/2,
        tags: [:route],
        description: "Total number of router dispatches, by route."
      ),
      counter("phoenix.router_dispatch.exception.count.total",
        event_name: [:phoenix, :router_dispatch, :exception],
        measurement: &inc_one/2,
        tags: [:route],
        description: "Total number of router dispatch exceptions, by route."
      ),
      distribution("phoenix.router_dispatch.stop.duration.seconds",
        event_name: [:phoenix, :router_dispatch, :stop],
        measurement: :duration,
        tags: [:route],
        unit: {:native, :second},
        reporter_options: [buckets: duration_buckets_seconds()],
        description: "Histogram of router dispatch duration, by route."
      ),

      # VM metrics (emitted by telemetry_poller default VM poller)
      last_value("vm.memory.total.bytes",
        event_name: [:vm, :memory],
        measurement: :total,
        unit: :byte,
        description: "Total amount of memory allocated by the Erlang VM."
      ),
      last_value("vm.system_counts.process_count",
        event_name: [:vm, :system_counts],
        measurement: :process_count,
        description: "Current BEAM process count."
      ),
      last_value("vm.system_counts.port_count",
        event_name: [:vm, :system_counts],
        measurement: :port_count,
        description: "Current BEAM port count."
      ),
      last_value("vm.total_run_queue_lengths.total",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :total,
        description: "Total run queue lengths (CPU + IO schedulers)."
      ),
      last_value("vm.total_run_queue_lengths.cpu",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :cpu,
        description: "CPU scheduler run queue length."
      ),
      last_value("vm.total_run_queue_lengths.io",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :io,
        description: "IO scheduler run queue length."
      ),

      # App metrics
      last_value("frontend_ex.cache.api_entries",
        event_name: [:frontend_ex, :cache],
        measurement: :api_entries,
        description: "Current entries in the standard API cache."
      ),
      last_value("frontend_ex.cache.swr_entries",
        event_name: [:frontend_ex, :cache],
        measurement: :swr_entries,
        description: "Current entries in the SWR API cache."
      )
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      {FrontendEx.Metrics, :dispatch_cache_stats, []}
    ]
  end

  defp duration_buckets_seconds do
    # Covers:
    # - warm-cache SSR (~sub-ms)
    # - cache misses dominated by upstream API latency (10s+ ms)
    [0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]
  end

  defp metrics_enabled? do
    Keyword.get(Application.get_env(:frontend_ex, :metrics, []), :enabled, true)
  end

  defp metrics_port do
    Keyword.get(Application.get_env(:frontend_ex, :metrics, []), :port, 9568)
  end

  defp metrics_ip do
    Keyword.get(Application.get_env(:frontend_ex, :metrics, []), :ip, {127, 0, 0, 1})
  end

  defp inc_one(_measurements, _metadata), do: 1
end
