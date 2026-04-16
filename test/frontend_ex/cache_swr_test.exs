defmodule FrontendEx.CacheSWRTest do
  use ExUnit.Case

  alias FrontendEx.Cache.SWR

  setup do
    clock = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: :clock))
    now_ms = fn -> Agent.get(clock, & &1) end

    name = __MODULE__.Cache
    start_supervised!({SWR, name: name, now_ms: now_ms, max_entries: 10})

    %{cache: name, clock: clock}
  end

  test "SWR: fresh serves cached, stale serves cached + refresh, expired fetches fresh", %{
    cache: cache,
    clock: clock
  } do
    parent = self()
    step = start_supervised!(Supervisor.child_spec({Agent, fn -> 0 end}, id: :step))

    fetch_fun = fn ->
      pid = self()
      n = Agent.get_and_update(step, fn n -> {n, n + 1} end)
      send(parent, {:fetch_started, n, pid})

      receive do
        :continue -> :ok
      after
        1_000 -> exit(:timeout)
      end

      case n do
        0 -> {:ok, "v1"}
        1 -> {:ok, "v2"}
        _ -> {:ok, "v3"}
      end
    end

    # Miss -> synchronous fetch.
    t0 = Task.async(fn -> SWR.get_or_fetch(cache, :k, 5_000, 20_000, fetch_fun) end)
    assert_receive {:fetch_started, 0, pid0}, 1_000
    send(pid0, :continue)
    assert {:ok, "v1"} = Task.await(t0, 1_000)

    # 0-5s: fresh from cache (no fetch).
    assert {:ok, "v1"} = SWR.get_or_fetch(cache, :k, 5_000, 20_000, fetch_fun)
    refute_receive {:fetch_started, 1, _pid}, 200

    # 5-20s: stale from cache + refresh in background (deduped).
    Agent.update(clock, fn _ -> 6_000 end)
    assert {:ok, "v1"} = SWR.get_or_fetch(cache, :k, 5_000, 20_000, fetch_fun)
    assert_receive {:fetch_started, 1, pid1}, 1_000

    Agent.update(clock, fn _ -> 7_000 end)
    assert {:ok, "v1"} = SWR.get_or_fetch(cache, :k, 5_000, 20_000, fetch_fun)
    refute_receive {:fetch_started, 2, _pid}, 200

    send(pid1, :continue)
    assert :ok = SWR.await_refresh(cache, :k, 1_000)

    # After refresh: cached value is updated and should be fresh.
    assert {:ok, "v2"} = SWR.get_or_fetch(cache, :k, 5_000, 20_000, fetch_fun)
    refute_receive {:fetch_started, 2, _pid}, 200

    # >20s: expired -> synchronous fetch before serving.
    Agent.update(clock, fn _ -> 28_000 end)
    t2 = Task.async(fn -> SWR.get_or_fetch(cache, :k, 5_000, 20_000, fetch_fun) end)
    assert_receive {:fetch_started, 2, pid2}, 1_000
    send(pid2, :continue)
    assert {:ok, "v3"} = Task.await(t2, 1_000)
  end

  test "SWR clears refresh_inflight if the refresh task dies", %{cache: cache, clock: clock} do
    assert {:ok, "v1"} = SWR.get_or_fetch(cache, :k, 5_000, 20_000, fn -> {:ok, "v1"} end)

    Agent.update(clock, fn _ -> 6_000 end)

    # Trigger a refresh task that dies before sending :refresh_done.
    assert {:ok, "v1"} =
             SWR.get_or_fetch(cache, :k, 5_000, 20_000, fn ->
               Process.exit(self(), :kill)
             end)

    # Should not hang waiting for a refresh that will never complete.
    assert :ok = SWR.await_refresh(cache, :k, 1_000)

    parent = self()

    # A subsequent stale read should be able to start a new refresh.
    assert {:ok, "v1"} =
             SWR.get_or_fetch(cache, :k, 5_000, 20_000, fn ->
               send(parent, :refresh_started)
               {:ok, "v2"}
             end)

    assert_receive :refresh_started, 1_000
    assert :ok = SWR.await_refresh(cache, :k, 1_000)

    assert {:ok, "v2"} =
             SWR.get_or_fetch(cache, :k, 5_000, 20_000, fn ->
               flunk("should be fresh")
             end)
  end

  test "SWR rejects invalid windows (stale_ms < fresh_ms)", %{cache: cache} do
    assert {:error, :invalid_window} = SWR.get_or_fetch(cache, :k, 10, 5, fn -> {:ok, "v"} end)
  end

  test "SWR does not crash if fetch_fun returns an unexpected value", %{cache: cache} do
    pid = Process.whereis(cache)
    assert is_pid(pid)

    assert {:error, {:invalid_fetch_return, :ok}} =
             SWR.get_or_fetch(cache, :k, 5_000, 20_000, fn -> :ok end)

    assert Process.alive?(pid)
  end

  describe "fetch task failure paths" do
    test "waiters receive error when fetch raises", %{cache: cache} do
      fetch = fn -> raise "boom" end

      assert {:error, {%RuntimeError{}, _stacktrace}} =
               SWR.get_or_fetch(cache, :k_raise, 5_000, 20_000, fetch)

      # GenServer survives; a subsequent fetch succeeds.
      assert Process.alive?(Process.whereis(cache))

      assert {:ok, :ok_val} =
               SWR.get_or_fetch(cache, :k_raise, 5_000, 20_000, fn -> {:ok, :ok_val} end)
    end

    test "waiters receive error when fetch process is externally killed", %{cache: cache} do
      parent = self()

      fetch = fn ->
        send(parent, {:fetch_pid, self()})

        receive do
          :never -> :unreachable
        end
      end

      caller =
        Task.async(fn -> SWR.get_or_fetch(cache, :k_kill, 5_000, 20_000, fetch) end)

      receive do
        {:fetch_pid, pid} -> Process.exit(pid, :kill)
      after
        1_000 -> flunk("fetch task never started")
      end

      assert {:error, {:task_down, :killed}} = Task.await(caller, 2_000)
      assert Process.alive?(Process.whereis(cache))
    end
  end
end
