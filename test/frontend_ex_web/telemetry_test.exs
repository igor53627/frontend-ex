defmodule FrontendExWeb.TelemetryTest do
  use ExUnit.Case, async: true

  test "request counters count events (1 per event), not duration" do
    metrics = FrontendExWeb.Telemetry.metrics()

    for name <- [
          [:phoenix, :endpoint, :stop, :count, :total],
          [:phoenix, :router_dispatch, :stop, :count, :total],
          [:phoenix, :router_dispatch, :exception, :count, :total]
        ] do
      metric =
        Enum.find(metrics, fn m ->
          match?(%Telemetry.Metrics.Counter{}, m) and m.name == name
        end)

      assert %Telemetry.Metrics.Counter{} = metric
      assert is_function(metric.measurement, 2)
      assert metric.measurement.(%{}, %{}) == 1
    end
  end
end
