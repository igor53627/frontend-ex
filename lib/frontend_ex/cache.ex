defmodule FrontendEx.Cache do
  @moduledoc false

  use GenServer

  @cleanup_interval_ms 60_000

  @type key :: term()
  @type value :: term()

  defstruct table: nil,
            index_table: nil,
            inflight: %{},
            now_ms: nil,
            max_entries: :infinity

  @type t :: %__MODULE__{
          table: :ets.tid(),
          index_table: :ets.tid(),
          inflight: %{optional(key()) => inflight()},
          now_ms: (-> non_neg_integer()),
          max_entries: :infinity | pos_integer()
        }

  @type inflight :: %{
          pid: pid(),
          ref: reference(),
          token: reference(),
          waiters: [GenServer.from()],
          ttl_ms: non_neg_integer()
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

  @spec get(GenServer.server(), key()) :: {:ok, value()} | :error
  def get(server, key) when is_atom(server) do
    # Direct ETS read. The prod hot path (`Client.get_or_fetch/4`) hits this
    # on every request; previously every read serialized through a single
    # GenServer.call. The table is `:protected`, so only the owning GenServer
    # writes — readers observe the last committed write without coordination.
    #
    # Instances started with an injected `now_ms` (tests) skip this path so
    # expiry is checked against the injected clock, not `System.monotonic_time`.
    if :persistent_term.get({__MODULE__, server, :direct_reads}, false) do
      direct_get(server, key)
    else
      GenServer.call(server, {:get, key})
    end
  end

  def get(server, key), do: GenServer.call(server, {:get, key})

  defp direct_get(server, key) do
    case :ets.lookup(data_table(server), key) do
      [{^key, value, _inserted_ms, expires_ms}] ->
        if System.monotonic_time(:millisecond) < expires_ms do
          {:ok, value}
        else
          :error
        end

      [] ->
        :error
    end
  rescue
    ArgumentError ->
      # Named table not registered (race with init or teardown).
      GenServer.call(server, {:get, key})
  end

  defp data_table(name) when is_atom(name), do: :"#{name}.data"

  @spec put(GenServer.server(), key(), value(), non_neg_integer()) :: :ok
  def put(server, key, value, ttl_ms) when is_integer(ttl_ms) and ttl_ms >= 0 do
    GenServer.call(server, {:put, key, value, ttl_ms})
  end

  @spec delete(GenServer.server(), key()) :: :ok
  def delete(server, key), do: GenServer.call(server, {:delete, key})

  @spec clear(GenServer.server()) :: :ok
  def clear(server), do: GenServer.call(server, :clear)

  @spec stats(GenServer.server()) :: %{entries: non_neg_integer(), inflight: non_neg_integer()}
  def stats(server), do: GenServer.call(server, :stats)

  @spec get_or_fetch(
          GenServer.server(),
          key(),
          non_neg_integer(),
          (-> {:ok, value()} | {:error, term()})
        ) ::
          {:ok, value()} | {:error, term()}
  def get_or_fetch(server, key, ttl_ms, fun)
      when is_integer(ttl_ms) and ttl_ms >= 0 and is_function(fun, 0) do
    GenServer.call(server, {:get_or_fetch, key, ttl_ms, fun}, :infinity)
  end

  @impl true
  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    injected_now_ms = Keyword.get(opts, :now_ms)
    now_ms = injected_now_ms || fn -> System.monotonic_time(:millisecond) end
    max_entries = Keyword.get(opts, :max_entries, :infinity)

    # Atom name + default clock → named, `:protected` table so `get/2` can
    # read directly. Any other shape (`{:via, ...}`, `{:global, _}`, or a
    # custom clock) falls back to an anonymous `:private` table; reads route
    # through `GenServer.call/2` as they did before this refactor.
    direct_reads? = is_atom(name) and is_nil(injected_now_ms)

    table =
      if direct_reads? do
        :ets.new(data_table(name), [:set, :protected, :named_table, read_concurrency: true])
      else
        :ets.new(__MODULE__, [:set, :private, read_concurrency: true])
      end

    index_table = :ets.new(__MODULE__, [:ordered_set, :private])

    if is_atom(name) do
      :persistent_term.put({__MODULE__, name, :direct_reads}, direct_reads?)
    end

    state = %__MODULE__{
      table: table,
      index_table: index_table,
      inflight: %{},
      now_ms: now_ms,
      max_entries: max_entries
    }

    schedule_cleanup()

    {:ok, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    case lookup(state, key) do
      {:ok, value, _inserted, _expires} -> {:reply, {:ok, value}, state}
      :error -> {:reply, :error, state}
    end
  end

  def handle_call({:put, key, value, ttl_ms}, _from, state) do
    state = put_entry(state, key, value, ttl_ms)
    {:reply, :ok, state}
  end

  def handle_call({:delete, key}, _from, state) do
    case :ets.take(state.table, key) do
      [{^key, _value, inserted_ms, _expires_ms}] ->
        _ = :ets.delete(state.index_table, {inserted_ms, key})

      [] ->
        :ok
    end

    {:reply, :ok, state}
  end

  def handle_call(:clear, _from, state) do
    _ = :ets.delete_all_objects(state.table)
    _ = :ets.delete_all_objects(state.index_table)

    # Unblock any callers waiting on inflight fetches; their task results will be ignored.
    Enum.each(state.inflight, fn {_key, %{ref: ref, waiters: waiters}} ->
      _ = Process.demonitor(ref, [:flush])
      Enum.each(waiters, &GenServer.reply(&1, {:error, :cleared}))
    end)

    {:reply, :ok, %{state | inflight: %{}}}
  end

  def handle_call(:stats, _from, state) do
    entries = :ets.info(state.table, :size) || 0
    inflight = map_size(state.inflight)

    max_entries =
      case state.max_entries do
        :infinity -> nil
        n when is_integer(n) and n > 0 -> n
        _ -> nil
      end

    {:reply, %{entries: entries, inflight: inflight, max_entries: max_entries}, state}
  end

  def handle_call({:get_or_fetch, key, ttl_ms, fun}, from, state) do
    case lookup(state, key) do
      {:ok, value, _inserted, _expires} ->
        {:reply, {:ok, value}, state}

      :error ->
        case state.inflight do
          %{^key => inflight} ->
            inflight = %{inflight | waiters: [from | inflight.waiters]}
            {:noreply, %{state | inflight: Map.put(state.inflight, key, inflight)}}

          %{} ->
            state = start_fetch(state, key, ttl_ms, fun, from)
            {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup_expired(state)
    schedule_cleanup()
    {:noreply, state}
  end

  def handle_info({:fetch_done, key, token, {:ok, value}}, state) do
    case state.inflight do
      %{^key => %{token: ^token, ref: ref, waiters: waiters, ttl_ms: ttl_ms}} ->
        _ = Process.demonitor(ref, [:flush])

        state =
          %{state | inflight: Map.delete(state.inflight, key)} |> put_entry(key, value, ttl_ms)

        Enum.each(waiters, &GenServer.reply(&1, {:ok, value}))
        {:noreply, state}

      _ ->
        # Stale message from an older task.
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

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) do
    case find_inflight_key(state.inflight, ref) do
      nil ->
        {:noreply, state}

      key ->
        {%{waiters: waiters}, inflight} = Map.pop(state.inflight, key)
        Enum.each(waiters, &GenServer.reply(&1, {:error, {:task_down, reason}}))
        {:noreply, %{state | inflight: inflight}}
    end
  end

  defp lookup(state, key) do
    now = state.now_ms.()

    case :ets.lookup(state.table, key) do
      [{^key, value, inserted_ms, expires_ms}] ->
        if now < expires_ms do
          {:ok, value, inserted_ms, expires_ms}
        else
          _ = :ets.delete(state.table, key)
          _ = :ets.delete(state.index_table, {inserted_ms, key})
          :error
        end

      [] ->
        :error
    end
  end

  defp put_entry(state, key, value, ttl_ms) do
    now = state.now_ms.()
    inserted_ms = now
    expires_ms = now + ttl_ms

    case :ets.lookup(state.table, key) do
      [{^key, _old_value, old_inserted_ms, _old_expires_ms}] ->
        _ = :ets.delete(state.index_table, {old_inserted_ms, key})

      [] ->
        :ok
    end

    _ = :ets.insert(state.table, {key, value, inserted_ms, expires_ms})
    _ = :ets.insert(state.index_table, {{inserted_ms, key}, true})

    state
    |> maybe_evict()
  end

  defp maybe_evict(%__MODULE__{max_entries: :infinity} = state), do: state

  defp maybe_evict(%__MODULE__{max_entries: max_entries} = state) when is_integer(max_entries) do
    size = :ets.info(state.table, :size)

    if size > max_entries do
      _ = evict_oldest(state, size - max_entries)
    end

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
          [{^key, _v, ^inserted_ms, _expires_ms}] ->
            _ = :ets.delete(state.table, key)
            evict_oldest(state, n - 1)

          _ ->
            # Stale index entry for a key that was updated/expired/removed.
            evict_oldest(state, n)
        end
    end
  end

  defp start_fetch(state, key, ttl_ms, fun, first_waiter) do
    parent = self()

    token = make_ref()

    {:ok, pid} =
      Task.start(fn ->
        result = safe_call(fun)
        send(parent, {:fetch_done, key, token, result})
      end)

    ref = Process.monitor(pid)

    inflight = %{
      pid: pid,
      ref: ref,
      token: token,
      waiters: [first_waiter],
      ttl_ms: ttl_ms
    }

    %{state | inflight: Map.put(state.inflight, key, inflight)}
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

  defp find_inflight_key(inflight, ref) do
    inflight
    |> Enum.find_value(fn {key, %{ref: r}} -> if r == ref, do: key, else: nil end)
  end

  defp schedule_cleanup do
    _ = Process.send_after(self(), :cleanup, @cleanup_interval_ms)
    :ok
  end

  defp cleanup_expired(state) do
    now = state.now_ms.()

    expired =
      :ets.foldl(
        fn {key, _value, inserted_ms, expires_ms}, acc ->
          if now >= expires_ms, do: [{key, inserted_ms} | acc], else: acc
        end,
        [],
        state.table
      )

    Enum.each(expired, fn {key, inserted_ms} ->
      _ = :ets.delete(state.table, key)
      _ = :ets.delete(state.index_table, {inserted_ms, key})
    end)
  end
end
