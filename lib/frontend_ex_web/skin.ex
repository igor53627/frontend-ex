defmodule FrontendExWeb.Skin do
  @moduledoc false

  @type t :: :classic | :s53627

  # `Application.get_env/3` is an ETS lookup (sub-microsecond). Caching the
  # resolved value in `:persistent_term` was considered but the test suite
  # mutates `:ff_skin` at runtime (see export_data_parity_test.exs) and a
  # cache would silently serve the pre-mutation value. The per-request cost
  # is a handful of microseconds — not a real hot-path concern for this SSR
  # app — so read-through is the right trade-off.
  @spec current() :: t()
  def current do
    case normalize(Application.get_env(:frontend_ex, :ff_skin, "53627")) do
      "classic" -> :classic
      "skin-classic" -> :classic
      "53627" -> :s53627
      "skin-53627" -> :s53627
      _ -> :s53627
    end
  end

  defp normalize(v) when is_binary(v), do: String.trim(v)
  defp normalize(v), do: v |> to_string() |> String.trim()
end
