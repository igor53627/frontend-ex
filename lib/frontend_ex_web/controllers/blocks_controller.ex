defmodule FrontendExWeb.BlocksController do
  use FrontendExWeb, :controller

  require Logger

  alias FrontendEx.Blockscout.Client
  alias FrontendEx.Format
  alias FrontendExWeb.BlockHTML
  alias FrontendExWeb.BlocksHTML

  @blocks_limit 50

  def index(conn, _params) do
    skin = FrontendExWeb.Skin.current()

    safe_empty = {:safe, ""}

    explorer_url = Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

    stats_path = "/api/v2/stats"
    blocks_path = "/api/v2/blocks?limit=#{@blocks_limit}"

    stats_task = Task.async(fn -> Client.get_json_cached(stats_path, :public) end)

    blocks_task =
      Task.async(fn ->
        Client.get_json_cached(blocks_path, :public)
      end)

    [stats_json, blocks_json] =
      await_many_ok([{stats_path, stats_task}, {blocks_path, blocks_task}], 10_000)

    {coin_price, gas_price} = derive_coin_gas(stats_json)
    blocks = parse_blocks(blocks_json)

    base_assigns = %{
      page_title: "",
      explorer_url: explorer_url,
      head_meta: safe_empty,
      styles: safe_empty,
      scripts: safe_empty,
      topbar: safe_empty,
      nav_home: "",
      nav_blocks: "",
      nav_txs: "",
      nav_tokens: "",
      nav_nfts: "",
      blocks: blocks,
      coin_price: coin_price,
      gas_price: gas_price
    }

    case skin do
      :classic ->
        styles = BlocksHTML.classic_styles(base_assigns)

        render(conn, :classic_content, %{
          base_assigns
          | page_title: "Blocks | Sepolia",
            nav_blocks: "active",
            styles: styles
        })

      :s53627 ->
        topbar = BlockHTML.s53627_topbar(base_assigns)

        render(conn, :s53627_content, %{
          base_assigns
          | page_title: "Blocks | Explorer",
            topbar: topbar
        })
    end
  end

  defp await_many_ok(labeled_tasks, timeout_ms)
       when is_list(labeled_tasks) and is_integer(timeout_ms) do
    labels_by_ref =
      Map.new(labeled_tasks, fn {label, %Task{ref: ref}} -> {ref, label} end)

    tasks = Enum.map(labeled_tasks, &elem(&1, 1))

    tasks
    |> Task.yield_many(timeout_ms)
    |> Enum.map(fn {task, res} ->
      label = Map.get(labels_by_ref, task.ref, "unknown")

      case res do
        {:ok, {:ok, json}} ->
          json

        {:ok, {:error, reason}} ->
          Logger.warning("blocks: upstream request failed",
            endpoint: label,
            reason: inspect(reason)
          )

          nil

        {:ok, other} ->
          Logger.warning("blocks: upstream request returned unexpected result",
            endpoint: label,
            result: inspect(other)
          )

          nil

        {:exit, reason} ->
          Logger.warning("blocks: upstream task crashed",
            endpoint: label,
            reason: inspect(reason)
          )

          nil

        nil ->
          Task.shutdown(task, :brutal_kill)

          Logger.warning("blocks: upstream request timed out",
            endpoint: label,
            timeout_ms: timeout_ms
          )

          nil
      end
    end)
  end

  defp derive_coin_gas(nil), do: {nil, nil}

  defp derive_coin_gas(%{} = stats_json) do
    coin_price =
      case stats_json["coin_price"] do
        v when is_binary(v) -> Format.format_price_with_commas(v)
        _ -> nil
      end

    gas_price =
      case get_in(stats_json, ["gas_prices", "average", "price"]) do
        v when is_number(v) ->
          Format.format_one_decimal(v)

        _ ->
          nil
      end

    {coin_price, gas_price}
  end

  defp derive_coin_gas(_), do: {nil, nil}

  defp parse_blocks(nil), do: []

  defp parse_blocks(%{} = json) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    items
    |> Enum.take(@blocks_limit)
    |> Enum.map(&display_block/1)
  end

  defp parse_blocks(_), do: []

  defp display_block(%{} = b) do
    height =
      case b["height"] do
        v when is_integer(v) -> v
        v when is_binary(v) -> parse_int_or(v, nil)
        _ -> nil
      end

    ts_raw = to_string(b["timestamp"] || "")

    miner_hash =
      case get_in(b, ["miner", "hash"]) do
        v when is_binary(v) and v != "" -> v
        _ -> nil
      end

    tx_count =
      case b["tx_count"] do
        v when is_integer(v) -> v
        v when is_binary(v) -> parse_int_or(v, 0)
        _ -> 0
      end

    %{
      height: height,
      time_ago: Format.format_blocks_time_ago(ts_raw),
      tx_count: tx_count,
      miner_hash: miner_hash,
      gas_used: format_optional_number_string(b["gas_used"]),
      gas_limit: format_optional_number_string(b["gas_limit"])
    }
  end

  defp parse_int_or(s, fallback) when is_binary(s) do
    case Integer.parse(s) do
      {n, ""} -> n
      _ -> fallback
    end
  end

  defp format_optional_number_string(nil), do: ""

  defp format_optional_number_string(v) when is_integer(v),
    do: v |> Integer.to_string() |> Format.format_number_with_commas()

  defp format_optional_number_string(v) when is_binary(v), do: Format.format_number_with_commas(v)
  defp format_optional_number_string(_), do: ""
end
