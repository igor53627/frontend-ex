defmodule FrontendEx.Blockscout.RequestAdapter.Stub do
  @moduledoc false

  @behaviour FrontendEx.Blockscout.RequestAdapter

  @impl true
  def request_raw(url) when is_binary(url) do
    agent =
      Application.get_env(:frontend_ex, :blockscout_stub_agent) ||
        raise "missing :frontend_ex, :blockscout_stub_agent for Stub request adapter"

    Agent.get_and_update(agent, fn state ->
      state = normalize_state(state)
      {result, state} = pop_result(state, url)
      {result, state}
    end)
  end

  defp normalize_state(%{script: _script, calls: _calls} = state), do: state
  defp normalize_state(script) when is_map(script), do: %{script: script, calls: %{}}

  defp normalize_state(other) do
    raise "invalid stub adapter state: #{inspect(other)}"
  end

  defp pop_result(%{script: script, calls: calls} = state, url) do
    calls = Map.update(calls, url, 1, &(&1 + 1))
    state = %{state | calls: calls}

    case Map.get(script, url) do
      [result | rest] ->
        script =
          if rest == [] do
            Map.delete(script, url)
          else
            Map.put(script, url, rest)
          end

        {result, %{state | script: script}}

      [] ->
        raise "stub adapter has no more queued results for #{url} (calls=#{calls[url]})"

      nil ->
        raise "stub adapter has no queued results for #{url}"
    end
  end
end
