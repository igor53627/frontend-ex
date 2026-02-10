defmodule FrontendExWeb.TxsController do
  use FrontendExWeb, :controller

  require Logger

  alias FrontendEx.Blockscout.Client
  alias FrontendEx.Blockscout.Cursor
  alias FrontendEx.Format
  alias FrontendExWeb.BlockHTML
  alias FrontendExWeb.TxsHTML

  @page_size_options [10, 25, 50, 100]
  @default_page_size 50

  def index(conn, params) when is_map(params) do
    skin = FrontendExWeb.Skin.current()

    safe_empty = {:safe, ""}

    explorer_url = Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

    page_size = normalize_page_size(params)

    cursor_query = cursor_query_from_params(params)

    is_first_page = is_nil(cursor_query)

    stats_path = "/api/v2/stats"
    txs_path = txs_path(page_size, cursor_query)

    stats_task = Task.async(fn -> Client.get_json_cached(stats_path, :public) end)

    txs_api_url = Application.get_env(:frontend_ex, :blockscout_txs_api_url)

    txs_task =
      Task.async(fn ->
        case txs_api_url do
          v when is_binary(v) and v != "" -> Client.get_json_cached_at(v, txs_path, :public)
          _ -> Client.get_json_cached(txs_path, :public)
        end
      end)

    [stats_json, txs_json] =
      await_many_ok([{stats_path, stats_task}, {txs_path, txs_task}], 10_000)

    {coin_price, gas_price, total_transactions_display} = derive_stats_fields(stats_json)
    {transactions, next_cursor} = parse_transactions_response(txs_json)

    page_label =
      if is_first_page do
        "Latest"
      else
        "Older"
      end

    page_size_options =
      Enum.map(@page_size_options, fn value ->
        %{
          value: value,
          selected: value == page_size
        }
      end)

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
      transactions: transactions,
      coin_price: coin_price,
      gas_price: gas_price,
      page_size: page_size,
      page_size_options: page_size_options,
      page_label: page_label,
      is_first_page: is_first_page,
      next_cursor: next_cursor,
      total_transactions_display: total_transactions_display
    }

    case skin do
      :classic ->
        styles = TxsHTML.classic_styles(base_assigns)

        render(conn, :classic_content, %{
          base_assigns
          | page_title: "Transactions | Sepolia",
            nav_txs: "active",
            styles: styles
        })

      :s53627 ->
        topbar = BlockHTML.s53627_topbar(base_assigns)

        render(conn, :s53627_content, %{
          base_assigns
          | page_title: "Transactions | Explorer",
            topbar: topbar
        })
    end
  end

  defp normalize_page_size(params) when is_map(params) do
    raw = Map.get(params, "ps") || Map.get(params, "limit") || ""

    parsed =
      case raw do
        v when is_integer(v) -> v
        v when is_binary(v) -> Integer.parse(String.trim(v))
        _ -> :error
      end

    value =
      case parsed do
        v when is_integer(v) -> v
        {v, ""} when is_integer(v) -> v
        _ -> @default_page_size
      end

    if value in @page_size_options, do: value, else: @default_page_size
  end

  defp cursor_query_from_params(params) when is_map(params) do
    cursor_raw =
      case Map.get(params, "cursor") do
        v when is_binary(v) -> String.trim(v)
        _ -> ""
      end

    cursor_raw = if cursor_raw == "", do: nil, else: cursor_raw

    cursor_query =
      case cursor_raw do
        v when is_binary(v) and v != "" ->
          # Plug typically URL-decodes query params; however, some proxies can
          # pre-decode and/or split query fragments. Be liberal in what we accept.
          v =
            if String.contains?(v, "%") do
              case Cursor.decode_cursor_value(v) do
                {:ok, decoded} -> decoded
                :error -> v
              end
            else
              v
            end

          merge_cursor_params(v, params)

        _ ->
          merge_cursor_params(nil, params)
      end

    case cursor_query do
      v when is_binary(v) ->
        v = String.trim(v)
        if v == "", do: nil, else: v

      _ ->
        nil
    end
  end

  defp merge_cursor_params(cursor_query, params) when is_map(params) do
    cursor_query =
      case cursor_query do
        v when is_binary(v) -> v
        _ -> ""
      end

    fragments = if cursor_query == "", do: [], else: [cursor_query]

    fragments =
      fragments
      |> maybe_append_cursor_param(cursor_query, "block_number", params)
      |> maybe_append_cursor_param(cursor_query, "index", params)
      |> maybe_append_cursor_param(cursor_query, "items_count", params)

    fragments =
      fragments
      |> Enum.flat_map(fn
        v when is_binary(v) -> String.split(v, "&", trim: true)
        _ -> []
      end)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    case fragments do
      [] -> nil
      _ -> Enum.join(fragments, "&")
    end
  end

  defp maybe_append_cursor_param(fragments, cursor_query, key, params)
       when is_list(fragments) and is_binary(cursor_query) and is_binary(key) and is_map(params) do
    if cursor_query != "" and String.contains?(cursor_query, key <> "=") do
      fragments
    else
      case normalize_numeric_param(params, key) do
        nil -> fragments
        v -> fragments ++ [key <> "=" <> v]
      end
    end
  end

  defp normalize_numeric_param(params, key) when is_map(params) and is_binary(key) do
    raw =
      case Map.get(params, key) do
        v when is_binary(v) -> String.trim(v)
        v when is_integer(v) and v >= 0 -> Integer.to_string(v)
        _ -> ""
      end

    cond do
      raw == "" -> nil
      String.match?(raw, ~r/^\d+$/) -> raw
      true -> nil
    end
  end

  defp txs_path(page_size, nil) when is_integer(page_size) do
    "/api/v2/transactions?items_count=#{page_size}"
  end

  defp txs_path(page_size, cursor_query) when is_integer(page_size) and is_binary(cursor_query) do
    if String.contains?(cursor_query, "items_count=") do
      "/api/v2/transactions?" <> cursor_query
    else
      "/api/v2/transactions?items_count=#{page_size}&" <> cursor_query
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
          Logger.warning("txs: upstream request failed", endpoint: label, reason: inspect(reason))
          nil

        {:ok, other} ->
          Logger.warning("txs: upstream request returned unexpected result",
            endpoint: label,
            result: inspect(other)
          )

          nil

        {:exit, reason} ->
          Logger.warning("txs: upstream task crashed", endpoint: label, reason: inspect(reason))
          nil

        nil ->
          Task.shutdown(task, :brutal_kill)

          Logger.warning("txs: upstream request timed out",
            endpoint: label,
            timeout_ms: timeout_ms
          )

          nil
      end
    end)
  end

  defp derive_stats_fields(nil), do: {nil, nil, nil}

  defp derive_stats_fields(%{} = stats_json) do
    coin_price =
      case stats_json["coin_price"] do
        v when is_binary(v) -> Format.format_price_with_commas(v)
        _ -> nil
      end

    gas_price =
      case get_in(stats_json, ["gas_prices", "average", "price"]) do
        v when is_number(v) -> Format.format_one_decimal(v)
        _ -> nil
      end

    total_transactions_display =
      case stats_json["total_transactions"] do
        v when is_binary(v) ->
          clean = String.replace(v, ",", "")
          Format.format_number_with_commas(clean)

        _ ->
          nil
      end

    {coin_price, gas_price, total_transactions_display}
  end

  defp derive_stats_fields(_), do: {nil, nil, nil}

  defp parse_transactions_response(nil), do: {[], nil}

  defp parse_transactions_response(%{} = json) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    next_cursor =
      case Map.get(json, "next_page_params") do
        nil -> nil
        other -> Cursor.encode_next_page_params(other)
      end

    transactions =
      items
      |> Enum.flat_map(fn
        %{} = tx -> [display_tx(tx)]
        _ -> []
      end)

    {transactions, next_cursor}
  end

  defp parse_transactions_response(_), do: {[], nil}

  defp display_tx(%{} = tx) do
    hash = to_string(tx["hash"] || "")

    from_hash =
      case get_in(tx, ["from", "hash"]) do
        v when is_binary(v) -> v
        _ -> ""
      end

    to_hash =
      case get_in(tx, ["to", "hash"]) do
        v when is_binary(v) -> v
        _ -> nil
      end

    value_raw = to_string(tx["value"] || "0")
    has_value = String.match?(value_raw, ~r/[1-9]/)

    fee =
      case get_in(tx, ["fee", "value"]) do
        v when is_binary(v) -> Format.format_wei_to_eth(v)
        _ -> nil
      end

    method =
      case tx["method"] do
        v when is_binary(v) -> Format.format_method_name(v)
        _ -> nil
      end

    block_number = parse_u64(tx["block_number"])

    age =
      case tx["timestamp"] do
        v when is_binary(v) -> Format.format_relative_time(v)
        _ -> "-"
      end

    value = Format.format_wei_to_eth(value_raw) <> " ETH"

    %{
      hash: hash,
      method: method,
      block_number: block_number,
      age: age,
      from_hash: from_hash,
      to_hash: to_hash,
      value: value,
      has_value: has_value,
      fee: fee
    }
  end

  defp parse_u64(v) when is_integer(v) and v >= 0, do: v

  defp parse_u64(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_u64(_), do: nil
end
