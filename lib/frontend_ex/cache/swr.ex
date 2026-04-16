defmodule FrontendEx.Cache.SWR do
  @moduledoc false

  use GenServer

  # Keep SWR cache from retaining entries forever (mirrors fast-frontend's "60s TTL for cleanup").
  @cleanup_ttl_ms 60_000
  @cleanup_interval_ms 60_000

  @type key :: term()
  @type value :: term()
  @type error :: term()

  defstruct table: nil,
            index_table: nil,
            inflight: %{},
            refresh_inflight: %{},
            refresh_waiters: %{},
            now_ms: nil,
            max_entries: :infinity

  @type t :: %__MODULE__{
          table: :ets.tid(),
          index_table: :ets.tid(),
          inflight: %{optional(key()) => inflight()},
          refresh_inflight: %{optional(key()) => refresh_inflight()},
          refresh_waiters: %{optional(key()) => [GenServer.from()]},
          now_ms: (-> non_neg_integer()),
          max_entries: :infinity | pos_integer()
        }

  @type inflight :: %{
          pid: pid(),
          ref: reference(),
          token: reference(),
          waiters: [GenServer.from()],
          fetch: (-> {:ok, value()} | {:error, error()})
        }

  @type refresh_inflight :: %{
          pid: pid(),
          ref: reference(),
          token: reference()
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Gets a value using stale-while-revalidate semantics.

  `fetch_fun` must return `{:ok, value}` or `{:error, reason}`.

  Behavior:
  - age < fresh_ms: return cached value
  - fresh_ms <= age < stale_ms: return cached value and refresh in background (deduped per key)
  - age >= stale_ms: fetch synchronously (coalesced per key)
  """
  @spec get_or_fetch(
          GenServer.server(),
          key(),
          non_neg_integer(),
          non_neg_integer(),
          (-> {:ok, value()} | {:error, error()})
        ) :: {:ok, value()} | {:error, error()}
  def get_or_fetch(server, key, fresh_ms, stale_ms, fetch_fun)
      when is_integer(fresh_ms) and fresh_ms >= 0 and is_integer(stale_ms) and stale_ms >= 0 and
             stale_ms >= fresh_ms and is_function(fetch_fun, 0) do
    GenServer.call(server, {:get_or_fetch, key, fresh_ms, stale_ms, fetch_fun}, :infinity)
  end

  def get_or_fetch(_server, _key, fresh_ms, stale_ms, _fetch_fun)
      when is_integer(fresh_ms) and fresh_ms >= 0 and is_integer(stale_ms) and stale_ms >= 0 and
             stale_ms < fresh_ms do
    {:error, :invalid_window}
  end

  @doc false
  @spec await_refresh(GenServer.server(), key(), timeout()) :: :ok
  def await_refresh(server, key, timeout \\ 1_000) do
    GenServer.call(server, {:await_refresh, key}, timeout)
  end

  @spec clear(GenServer.server()) :: :ok
  def clear(server), do: GenServer.call(server, :clear)

  @spec stats(GenServer.server()) :: %{entries: non_neg_integer(), inflight: non_neg_integer()}
  def stats(server), do: GenServer.call(server, :stats)

  @impl true
  def init(opts) do
    table = :ets.new(__MODULE__, [:set, :private, read_concurrency: true])
    index_table = :ets.new(__MODULE__, [:ordered_set, :private])
    now_ms = Keyword.get(opts, :now_ms, fn -> System.monotonic_time(:millisecond) end)
    max_entries = Keyword.get(opts, :max_entries, :infinity)

    state = %__MODULE__{
      table: table,
      index_table: index_table,
      inflight: %{},
      refresh_inflight: %{},
      refresh_waiters: %{},
      now_ms: now_ms,
      max_entries: max_entries
    }

    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call(:clear, _from, state) do
    _ = :ets.delete_all_objects(state.table)
    _ = :ets.delete_all_objects(state.index_table)

    # Unblock any callers waiting on inflight fetches/refreshes; task results will be ignored.
    Enum.each(state.inflight, fn {_key, %{ref: ref, waiters: waiters}} ->
      _ = Process.demonitor(ref, [:flush])
      Enum.each(waiters, &GenServer.reply(&1, {:error, :cleared}))
    end)

    Enum.each(state.refresh_inflight, fn {_key, %{ref: ref}} ->
      _ = Process.demonitor(ref, [:flush])
    end)

    Enum.each(state.refresh_waiters, fn {_key, waiters} ->
      Enum.each(waiters, &GenServer.reply(&1, :ok))
    end)

    {:reply, :ok, %{state | inflight: %{}, refresh_inflight: %{}, refresh_waiters: %{}}}
  end

  def handle_call(:stats, _from, state) do
    entries = :ets.info(state.table, :size) || 0
    inflight = map_size(state.inflight)
    refresh_inflight = map_size(state.refresh_inflight)

    max_entries =
      case state.max_entries do
        :infinity -> nil
        n when is_integer(n) and n > 0 -> n
        _ -> nil
      end

    {:reply,
     %{
       entries: entries,
       inflight: inflight,
       refresh_inflight: refresh_inflight,
       max_entries: max_entries
     }, state}
  end

  def handle_call({:await_refresh, key}, from, state) do
    if Map.has_key?(state.refresh_inflight, key) do
      waiters = Map.get(state.refresh_waiters, key, [])

      {:noreply,
       %{state | refresh_waiters: Map.put(state.refresh_waiters, key, [from | waiters])}}
    else
      {:reply, :ok, state}
    end
  end

  def handle_call({:get_or_fetch, key, fresh_ms, stale_ms, fetch_fun}, from, state) do
    now = state.now_ms.()

    case :ets.lookup(state.table, key) do
      [{^key, value, inserted_ms}] ->
        age = now - inserted_ms

        cond do
          age < fresh_ms ->
            {:reply, {:ok, value}, state}

          age < stale_ms ->
            state = ensure_refresh(state, key, fetch_fun)
            {:reply, {:ok, value}, state}

          true ->
            state = start_fetch(state, key, fetch_fun, from)
            {:noreply, state}
        end

      [] ->
        state = start_fetch(state, key, fetch_fun, from)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    cutoff_ms = state.now_ms.() - @cleanup_ttl_ms
    _ = evict_before(state, cutoff_ms)
    schedule_cleanup()
    {:noreply, state}
  end

  def handle_info({:fetch_done, key, token, {:ok, value}}, state) do
    case state.inflight do
      %{^key => %{token: ^token, ref: ref, waiters: waiters}} ->
        _ = Process.demonitor(ref, [:flush])
        state = %{state | inflight: Map.delete(state.inflight, key)} |> put_entry(key, value)
        Enum.each(waiters, &GenServer.reply(&1, {:ok, value}))
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:fetch_done, key, token, {:error, reason}}, state) do
    case state.inflight do
      %{^key => %{token: ^token, ref: ref, waiters: waiters}} ->
        _ = Process.demonitor(ref, [:flush])
        Enum.each(waiters, &GenServer.reply(&1, {:error, reason}))
        {:noreply, %{state | inflight: Map.delete(state.inflight, key)}}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:refresh_done, key, token, {:ok, value}}, state) do
    case state.refresh_inflight do
      %{^key => %{token: ^token, ref: ref}} ->
        _ = Process.demonitor(ref, [:flush])
        state = %{state | refresh_inflight: Map.delete(state.refresh_inflight, key)}
        state = put_entry(state, key, value)
        state = reply_refresh_waiters(state, key)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:refresh_done, key, token, {:error, _reason}}, state) do
    case state.refresh_inflight do
      %{^key => %{token: ^token, ref: ref}} ->
        _ = Process.demonitor(ref, [:flush])
        state = %{state | refresh_inflight: Map.delete(state.refresh_inflight, key)}
        state = reply_refresh_waiters(state, key)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case find_inflight_key(state.inflight, ref) do
      nil ->
        case find_refresh_key(state.refresh_inflight, ref) do
          nil ->
            {:noreply, state}

          key ->
            state = %{state | refresh_inflight: Map.delete(state.refresh_inflight, key)}
            state = reply_refresh_waiters(state, key)
            {:noreply, state}
        end

      key ->
        %{waiters: waiters} = state.inflight[key]
        Enum.each(waiters, &GenServer.reply(&1, {:error, {:task_down, reason}}))
        {:noreply, %{state | inflight: Map.delete(state.inflight, key)}}
    end
  end

  defp ensure_refresh(state, key, fetch_fun) do
    if Map.has_key?(state.refresh_inflight, key) do
      state
    else
      parent = self()
      token = make_ref()
      {:ok, pid} = start_refresh_task(parent, key, token, fetch_fun)
      ref = Process.monitor(pid)

      inflight = %{
        pid: pid,
        ref: ref,
        token: token
      }

      %{state | refresh_inflight: Map.put(state.refresh_inflight, key, inflight)}
    end
  end

  defp start_refresh_task(parent, key, token, fetch_fun) do
    Task.Supervisor.start_child(task_supervisor(), fn ->
      result = safe_call(fetch_fun)
      send(parent, {:refresh_done, key, token, result})
    end)
  end

  defp start_fetch(state, key, fetch_fun, first_waiter) do
    case state.inflight do
      %{^key => inflight} ->
        inflight = %{inflight | waiters: [first_waiter | inflight.waiters]}
        %{state | inflight: Map.put(state.inflight, key, inflight)}

      %{} ->
        parent = self()
        token = make_ref()

        {:ok, pid} =
          Task.Supervisor.start_child(task_supervisor(), fn ->
            result = safe_call(fetch_fun)
            send(parent, {:fetch_done, key, token, result})
          end)

        ref = Process.monitor(pid)

        inflight = %{
          pid: pid,
          ref: ref,
          token: token,
          waiters: [first_waiter],
          fetch: fetch_fun
        }

        %{state | inflight: Map.put(state.inflight, key, inflight)}
    end
  end

  defp put_entry(state, key, value) do
    inserted_ms = state.now_ms.()

    case :ets.lookup(state.table, key) do
      [{^key, _old_value, old_inserted_ms}] ->
        _ = :ets.delete(state.index_table, {old_inserted_ms, key})

      [] ->
        :ok
    end

    _ = :ets.insert(state.table, {key, value, inserted_ms})
    _ = :ets.insert(state.index_table, {{inserted_ms, key}, true})
    state |> maybe_evict()
  end

  defp maybe_evict(state) do
    state
    |> maybe_evict_over_capacity()
    |> maybe_evict_too_old()
  end

  defp maybe_evict_over_capacity(%__MODULE__{max_entries: :infinity} = state), do: state

  defp maybe_evict_over_capacity(%__MODULE__{max_entries: max_entries} = state)
       when is_integer(max_entries) do
    size = :ets.info(state.table, :size)

    if size > max_entries do
      _ = evict_oldest(state, size - max_entries)
    end

    state
  end

  defp maybe_evict_too_old(state) do
    cutoff_ms = state.now_ms.() - @cleanup_ttl_ms
    _ = evict_before(state, cutoff_ms)
    state
  end

  defp evict_oldest(_state, n) when n <= 0, do: :ok

  defp evict_oldest(state, n) do
    case :ets.first(state.index_table) do
      :"$end_of_table" ->
        :ok

      {inserted_ms, key} ->
        _ = :ets.delete(state.index_table, {inserted_ms, key})

        case :ets.lookup(state.table, key) do
          [{^key, _v, ^inserted_ms}] ->
            _ = :ets.delete(state.table, key)
            evict_oldest(state, n - 1)

          _ ->
            # Stale index entry for a key that was updated/removed.
            evict_oldest(state, n)
        end
    end
  end

  defp evict_before(_state, cutoff_ms) when not is_integer(cutoff_ms), do: :ok

  defp evict_before(_state, cutoff_ms) when cutoff_ms <= 0, do: :ok

  defp evict_before(state, cutoff_ms) do
    case :ets.first(state.index_table) do
      :"$end_of_table" ->
        :ok

      {inserted_ms, key} when is_integer(inserted_ms) and inserted_ms < cutoff_ms ->
        _ = :ets.delete(state.index_table, {inserted_ms, key})

        case :ets.lookup(state.table, key) do
          [{^key, _v, ^inserted_ms}] ->
            _ = :ets.delete(state.table, key)

          _ ->
            :ok
        end

        evict_before(state, cutoff_ms)

      _ ->
        :ok
    end
  end

  defp safe_call(fun) do
    try do
      case fun.() do
        {:ok, _} = ok -> ok
        {:error, _} = err -> err
        other -> {:error, {:invalid_fetch_return, other}}
      end
    rescue
      e -> {:error, {e, __STACKTRACE__}}
    catch
      kind, reason -> {:error, {kind, reason}}
    end
  end

  defp reply_refresh_waiters(state, key) do
    waiters = Map.get(state.refresh_waiters, key, [])
    Enum.each(waiters, &GenServer.reply(&1, :ok))
    %{state | refresh_waiters: Map.delete(state.refresh_waiters, key)}
  end

  # Which Task.Supervisor to use for fetch/refresh. Shared with FrontendEx.Cache.
  defp task_supervisor do
    Application.get_env(:frontend_ex, :cache_task_supervisor, FrontendEx.Cache.TaskSupervisor)
  end

  defp schedule_cleanup do
    _ = Process.send_after(self(), :cleanup, @cleanup_interval_ms)
    :ok
  end

  defp find_inflight_key(inflight, ref) do
    inflight
    |> Enum.find_value(fn {key, %{ref: r}} -> if r == ref, do: key, else: nil end)
  end

  defp find_refresh_key(refresh_inflight, ref) do
    refresh_inflight
    |> Enum.find_value(fn {key, %{ref: r}} -> if r == ref, do: key, else: nil end)
  end
end
