defmodule FrontendEx.CacheTest do
  use ExUnit.Case

  alias FrontendEx.Cache

  setup do
    clock = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: :clock))
    now_ms = fn -> Agent.get(clock, & &1) end

    name = __MODULE__.Cache
    start_supervised!({Cache, name: name, now_ms: now_ms, max_entries: 10})

    %{cache: name, clock: clock}
  end

  test "TTL expiry removes entries and triggers refetch", %{cache: cache, clock: clock} do
    counter = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: :counter))

    fetch = fn ->
      {:ok, Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)}
    end

    assert {:ok, 1} = Cache.get_or_fetch(cache, :k, 100, fetch)
    assert {:ok, 1} = Cache.get_or_fetch(cache, :k, 100, fetch)

    Agent.update(clock, &(&1 + 101))
    assert {:ok, 2} = Cache.get_or_fetch(cache, :k, 100, fetch)
  end

  test "coalesces concurrent fetches per key", %{cache: cache} do
    parent = self()
    counter = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: :counter))

    fetch = fn ->
      pid = self()
      Agent.update(counter, &(&1 + 1))
      send(parent, {:fetch_started, pid})

      receive do
        :continue -> :ok
      after
        1_000 -> exit(:timeout)
      end

      {:ok, "v"}
    end

    t1 = Task.async(fn -> Cache.get_or_fetch(cache, :k2, 1_000, fetch) end)
    assert_receive {:fetch_started, pid}, 1_000

    t2 = Task.async(fn -> Cache.get_or_fetch(cache, :k2, 1_000, fetch) end)
    refute_receive {:fetch_started, _}, 200

    send(pid, :continue)

    assert {:ok, "v"} = Task.await(t1, 1_000)
    assert {:ok, "v"} = Task.await(t2, 1_000)
    assert Agent.get(counter, & &1) == 1
  end

  describe "direct ETS read path" do
    # Separate setup: no injected clock, so the direct-read path is enabled.
    setup do
      name = :"#{__MODULE__}.DirectReads"
      start_supervised!({Cache, name: name, max_entries: 10})
      %{cache: name}
    end

    test "get/2 returns fresh values via direct ETS read", %{cache: cache} do
      :ok = Cache.put(cache, :k, "v", 5_000)
      assert {:ok, "v"} = Cache.get(cache, :k)
    end

    test "get/2 returns :error for missing keys", %{cache: cache} do
      assert :error = Cache.get(cache, :missing)
    end

    test "get/2 treats expired entries as :error", %{cache: cache} do
      :ok = Cache.put(cache, :k, "v", 0)
      # With ttl_ms=0 the entry is instantly expired under monotonic time.
      # Small sleep to guarantee monotonic tick moves past expiry.
      Process.sleep(5)
      assert :error = Cache.get(cache, :k)
    end
  end
end
