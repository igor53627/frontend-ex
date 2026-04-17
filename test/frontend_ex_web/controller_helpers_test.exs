defmodule FrontendExWeb.ControllerHelpersTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias FrontendExWeb.ControllerHelpers

  describe "safe_empty/0" do
    test "returns the safe empty iodata tuple" do
      assert ControllerHelpers.safe_empty() == {:safe, ""}
    end
  end

  describe "explorer_url/0" do
    setup do
      prior = Application.get_env(:frontend_ex, :blockscout_url)
      on_exit(fn -> Application.put_env(:frontend_ex, :blockscout_url, prior) end)
      :ok
    end

    test "returns the configured URL" do
      Application.put_env(:frontend_ex, :blockscout_url, "https://example.test")
      assert ControllerHelpers.explorer_url() == "https://example.test"
    end

    test "falls back to the default when unset" do
      Application.delete_env(:frontend_ex, :blockscout_url)
      assert ControllerHelpers.explorer_url() == "https://sepolia.53627.org"
    end
  end

  describe "base_assigns/1" do
    test "returns defaults when no extras are given" do
      assigns = ControllerHelpers.base_assigns()
      assert assigns.page_title == ""
      assert assigns.head_meta == {:safe, ""}
      assert assigns.styles == {:safe, ""}
      assert assigns.scripts == {:safe, ""}
      assert assigns.topbar == {:safe, ""}
      assert assigns.nav_home == ""
      assert assigns.nav_blocks == ""
      assert assigns.nav_txs == ""
      assert assigns.nav_tokens == ""
      assert assigns.nav_nfts == ""
      assert is_binary(assigns.explorer_url)
    end

    test "extras merge on top of defaults" do
      assigns = ControllerHelpers.base_assigns(%{nav_home: "active", extra: 42})
      assert assigns.nav_home == "active"
      assert assigns.extra == 42
      assert assigns.nav_blocks == ""
    end

    test "accepts a keyword list" do
      assigns = ControllerHelpers.base_assigns(page_title: "Home")
      assert assigns.page_title == "Home"
    end
  end

  describe "await_ok/4" do
    test "returns the JSON for an ok task" do
      task = Task.async(fn -> {:ok, %{"k" => 1}} end)
      assert ControllerHelpers.await_ok(task, "test", "stats") == %{"k" => 1}
    end

    test "logs and returns nil on error task" do
      task = Task.async(fn -> {:error, :boom} end)

      log =
        capture_log(fn ->
          assert ControllerHelpers.await_ok(task, "test", "stats") == nil
        end)

      assert log =~ "test: upstream request failed"
    end

    test "logs and returns nil on timeout; task is shut down" do
      task = Task.async(fn -> Process.sleep(500) end)
      task_pid = task.pid

      log =
        capture_log(fn ->
          assert ControllerHelpers.await_ok(task, "test", "stats", 50) == nil
        end)

      assert log =~ "test: upstream request timed out"
      # `Task.shutdown/2` with `:brutal_kill` should terminate the task.
      refute Process.alive?(task_pid)
    end

    test "logs and returns nil on unexpected return shape" do
      task = Task.async(fn -> :not_a_tuple end)

      log =
        capture_log(fn ->
          assert ControllerHelpers.await_ok(task, "test", "stats") == nil
        end)

      assert log =~ "test: upstream request returned unexpected result"
    end
  end

  describe "await_many_ok/3" do
    test "returns values in order" do
      task_a = Task.async(fn -> {:ok, :a} end)
      task_b = Task.async(fn -> {:ok, :b} end)

      assert ControllerHelpers.await_many_ok(
               [{"a", task_a}, {"b", task_b}],
               "test"
             ) == [:a, :b]
    end

    test "nil entries replace failed/errored tasks; order preserved" do
      task_ok = Task.async(fn -> {:ok, :fine} end)
      task_err = Task.async(fn -> {:error, :nope} end)

      log =
        capture_log(fn ->
          assert ControllerHelpers.await_many_ok(
                   [{"ok", task_ok}, {"err", task_err}],
                   "test"
                 ) == [:fine, nil]
        end)

      assert log =~ "test: upstream request failed"
    end

    test "times out slow tasks and logs" do
      task = Task.async(fn -> Process.sleep(500) end)

      log =
        capture_log(fn ->
          assert ControllerHelpers.await_many_ok([{"slow", task}], "test", 50) == [nil]
        end)

      assert log =~ "test: upstream request timed out"
    end

    test "does not misclassify completed task as timeout with zero window" do
      # Regression for the late-reply recovery in await_many_ok/3's
      # `Task.shutdown/2` branch. Deterministic synchronisation: gate the
      # task on a `:continue` message, then peek (via `Process.info`, NOT
      # `receive`) until the task's reply tuple is sitting in our mailbox.
      # By the time `await_many_ok/3` is called, either yield_many sees it
      # directly OR shutdown picks up the pending message — the visible
      # outcome is the same: the value is returned and no timeout is logged.
      #
      # Using `receive` to detect the reply would consume it, causing a
      # real timeout. `:erlang.process_info(self(), :messages)` reads the
      # mailbox without mutation.
      task =
        Task.async(fn ->
          receive do
            :continue -> :ok
          end

          {:ok, :late}
        end)

      send(task.pid, :continue)
      await_task_reply_in_mailbox(task.ref)

      log =
        capture_log(fn ->
          assert ControllerHelpers.await_many_ok([{"late", task}], "test", 0) == [:late]
        end)

      refute log =~ "timed out"
      refute log =~ "crashed"
    end

    # Spin until `{ref, _}` appears in the mailbox, without consuming it.
    defp await_task_reply_in_mailbox(ref, attempts \\ 100)

    defp await_task_reply_in_mailbox(_ref, 0), do: flunk("task reply never arrived")

    defp await_task_reply_in_mailbox(ref, attempts) do
      {:messages, msgs} = :erlang.process_info(self(), :messages)

      if Enum.any?(msgs, fn
           {^ref, _} -> true
           _ -> false
         end) do
        :ok
      else
        Process.sleep(1)
        await_task_reply_in_mailbox(ref, attempts - 1)
      end
    end
  end

  describe "derive_coin_gas/1" do
    test "returns {nil, nil} for nil input" do
      assert ControllerHelpers.derive_coin_gas(nil) == {nil, nil}
    end

    test "returns {nil, nil} for unexpected shape" do
      assert ControllerHelpers.derive_coin_gas("nope") == {nil, nil}
    end

    test "formats coin_price and gas_price when present" do
      stats = %{
        "coin_price" => "1234.56",
        "gas_prices" => %{"average" => %{"price" => 12.345}}
      }

      {coin, gas} = ControllerHelpers.derive_coin_gas(stats)
      assert is_binary(coin)
      assert is_binary(gas)
    end

    test "returns {nil, nil} for empty stats map" do
      assert ControllerHelpers.derive_coin_gas(%{}) == {nil, nil}
    end

    test "partial stats map: only coin_price present" do
      {coin, gas} = ControllerHelpers.derive_coin_gas(%{"coin_price" => "1.00"})
      assert is_binary(coin)
      assert gas == nil
    end
  end
end
