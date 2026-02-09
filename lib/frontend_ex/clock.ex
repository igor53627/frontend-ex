defmodule FrontendEx.Clock do
  @moduledoc false

  @spec utc_now() :: DateTime.t()
  def utc_now do
    case Application.get_env(:frontend_ex, :clock_utc_now) do
      nil ->
        DateTime.utc_now()

      %DateTime{} = dt ->
        dt

      fun when is_function(fun, 0) ->
        fun.()

      {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, a)

      other ->
        raise "invalid :frontend_ex, :clock_utc_now: #{inspect(other)}"
    end
  end
end
