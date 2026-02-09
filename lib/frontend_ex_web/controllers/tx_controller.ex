defmodule FrontendExWeb.TxController do
  use FrontendExWeb, :controller

  alias FrontendEx.Blockscout.Client
  alias FrontendEx.Format
  alias FrontendExWeb.BlockHTML
  alias FrontendExWeb.TxHTML

  @task_timeout_ms 10_000
  @tx_hash_re ~r/\A0x[0-9a-fA-F]{64}\z/i
  @eth_address_re ~r/\A0x[0-9a-fA-F]{40}\z/i

  def show(conn, %{"hash" => hash}) when is_binary(hash) do
    hash = String.trim(hash)

    if not valid_tx_hash?(hash) do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(404, "Transaction not found")
    else
      skin = FrontendExWeb.Skin.current()

      safe_empty = {:safe, ""}

      explorer_url =
        Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

      base_url = Application.get_env(:frontend_ex, :base_url, "https://fast.53627.org")

      stats_task = Task.async(fn -> Client.get_json_cached("/api/v2/stats", :public) end)

      tx_task =
        Task.async(fn -> Client.get_json_cached("/api/v2/transactions/#{hash}", :public) end)

      logs_task =
        Task.async(fn -> Client.get_json_cached("/api/v2/transactions/#{hash}/logs", :public) end)

      blocks_task =
        Task.async(fn ->
          # Rust uses SWR for latest blocks; this is only used for confirmations.
          Client.get_json_swr("/api/v2/blocks?limit=1", :public)
        end)

      [stats_json, tx_json, logs_json, blocks_json] =
        await_ok_many([stats_task, tx_task, logs_task, blocks_task], @task_timeout_ms)

      if is_nil(tx_json) do
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Transaction not found")
      else
        {coin_price, gas_price} = derive_coin_gas(stats_json)

        logs_count = parse_logs_count(logs_json)
        latest_block_height = parse_latest_block_height(blocks_json)

        display_tx =
          tx_json
          |> parse_tx()
          |> maybe_format_method()
          |> with_confirmations(latest_block_height)

        {from_is_contract_like, from_is_verified, to_is_contract_like, to_is_verified} =
          address_flags(display_tx)

        {fee_eth, timestamp_relative, timestamp_readable, method_id} =
          derive_tx_display_fields(display_tx, skin)

        {gas_display, gas_percentage} = gas_fields(display_tx.gas_used, display_tx.gas_limit)

        gas_price_eth =
          if display_tx.gas_price,
            do: Format.format_wei_to_eth_exact(display_tx.gas_price),
            else: nil

        gas_price_gwei =
          if display_tx.gas_price, do: Format.format_wei_to_gwei(display_tx.gas_price), else: nil

        base_fee_gwei =
          if display_tx.base_fee_per_gas,
            do: Format.format_wei_to_gwei(display_tx.base_fee_per_gas),
            else: nil

        max_fee_gwei =
          if display_tx.max_fee_per_gas,
            do: Format.format_wei_to_gwei(display_tx.max_fee_per_gas),
            else: nil

        max_priority_fee_gwei =
          if display_tx.max_priority_fee_per_gas,
            do: Format.format_wei_to_gwei(display_tx.max_priority_fee_per_gas),
            else: nil

        base_assigns = %{
          page_title: "",
          explorer_url: explorer_url,
          base_url: base_url,
          head_meta: safe_empty,
          styles: safe_empty,
          scripts: safe_empty,
          topbar: safe_empty,
          nav_home: "",
          nav_blocks: "",
          nav_txs: "",
          nav_tokens: "",
          nav_nfts: "",
          tx: display_tx,
          from_is_contract_like: from_is_contract_like,
          from_is_verified: from_is_verified,
          to_is_contract_like: to_is_contract_like,
          to_is_verified: to_is_verified,
          fee_eth: fee_eth,
          timestamp_relative: timestamp_relative,
          timestamp_readable: timestamp_readable,
          method_id: method_id,
          gas_display: gas_display,
          gas_percentage: gas_percentage,
          gas_price_eth: gas_price_eth,
          gas_price_gwei: gas_price_gwei,
          base_fee_gwei: base_fee_gwei,
          max_fee_gwei: max_fee_gwei,
          max_priority_fee_gwei: max_priority_fee_gwei,
          logs_count: logs_count,
          coin_price: coin_price,
          gas_price: gas_price
        }

        case skin do
          :classic ->
            head_meta = TxHTML.classic_head_meta(base_assigns)
            styles = TxHTML.classic_styles(base_assigns)

            render(conn, :classic_content, %{
              base_assigns
              | page_title: "Transaction #{display_tx.hash} | Sepolia",
                head_meta: head_meta,
                styles: styles
            })

          :s53627 ->
            head_meta = TxHTML.s53627_head_meta(base_assigns)
            topbar = BlockHTML.s53627_topbar(base_assigns)

            render(conn, :s53627_content, %{
              base_assigns
              | page_title: "Transaction #{display_tx.hash} | Explorer",
                head_meta: head_meta,
                topbar: topbar
            })
        end
      end
    end
  end

  def internal(conn, %{"hash" => hash}) when is_binary(hash) do
    redirect_to_overview(conn, hash)
  end

  def logs(conn, %{"hash" => hash}) when is_binary(hash) do
    redirect_to_overview(conn, hash)
  end

  def state(conn, %{"hash" => hash}) when is_binary(hash) do
    redirect_to_overview(conn, hash)
  end

  def card(conn, %{"hash" => hash}) when is_binary(hash) do
    redirect_to_overview(conn, hash)
  end

  defp redirect_to_overview(conn, hash) when is_binary(hash) do
    hash = String.trim(hash)

    if valid_tx_hash?(hash) do
      redirect(conn, to: "/tx/#{hash}")
    else
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(404, "Transaction not found")
    end
  end

  defp valid_tx_hash?(hash) when is_binary(hash) do
    String.match?(String.trim(hash), @tx_hash_re)
  end

  defp valid_eth_address?(address) when is_binary(address) do
    String.match?(String.trim(address), @eth_address_re)
  end

  defp await_ok_many(tasks, timeout_ms)
       when is_list(tasks) and is_integer(timeout_ms) and timeout_ms >= 0 do
    tasks
    |> Task.yield_many(timeout_ms)
    |> Enum.map(fn {task, res} ->
      json =
        case res do
          {:ok, {:ok, v}} -> v
          {:ok, {:error, _}} -> nil
          {:exit, _} -> nil
          nil -> nil
        end

      if is_nil(res) do
        _ = Task.shutdown(task, :brutal_kill)
      end

      json
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
          :io_lib.format("~.1f", [v]) |> IO.iodata_to_binary()

        _ ->
          nil
      end

    {coin_price, gas_price}
  end

  defp parse_logs_count(%{} = logs_json) do
    case logs_json["items"] do
      items when is_list(items) -> length(items)
      _ -> 0
    end
  end

  defp parse_logs_count(_), do: 0

  defp parse_latest_block_height(%{} = blocks_json) do
    items =
      case blocks_json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    case List.first(items) do
      %{"height" => h} when is_integer(h) -> h
      %{"height" => h} when is_binary(h) -> parse_u64(h)
      _ -> nil
    end
  end

  defp parse_latest_block_height(_), do: nil

  defp parse_tx(%{} = tx_json) do
    hash = to_string(tx_json["hash"] || "")

    from_hash =
      case get_in(tx_json, ["from", "hash"]) do
        v when is_binary(v) -> v
        _ -> ""
      end

    to_hash =
      case get_in(tx_json, ["to", "hash"]) do
        v when is_binary(v) -> v
        _ -> nil
      end

    %{
      hash: hash,
      block_number: parse_u64(tx_json["block_number"]),
      from: %{hash: from_hash},
      to: if(to_hash, do: %{hash: to_hash}, else: nil),
      value: to_string(tx_json["value"] || "0"),
      gas_used: normalize_opt_string(tx_json["gas_used"]),
      gas_price: normalize_opt_string(tx_json["gas_price"]),
      gas_limit: normalize_opt_string(tx_json["gas_limit"]),
      fee: parse_fee(tx_json["fee"]),
      status: normalize_opt_string(tx_json["status"]),
      timestamp: normalize_opt_string(tx_json["timestamp"]),
      confirmations: nil,
      method: normalize_opt_string(tx_json["method"]),
      tx_type: parse_u64(tx_json["type"]),
      base_fee_per_gas: normalize_opt_string(tx_json["base_fee_per_gas"]),
      max_fee_per_gas: normalize_opt_string(tx_json["max_fee_per_gas"]),
      max_priority_fee_per_gas: normalize_opt_string(tx_json["max_priority_fee_per_gas"]),
      raw_input: normalize_opt_string(tx_json["raw_input"])
    }
  end

  defp parse_tx(_), do: nil

  defp parse_fee(%{"value" => v}) when is_binary(v), do: %{value: v}
  defp parse_fee(_), do: nil

  defp normalize_opt_string(v) when is_binary(v), do: String.trim(v)
  defp normalize_opt_string(_), do: nil

  defp maybe_format_method(nil), do: nil

  defp maybe_format_method(%{} = tx) do
    method =
      case tx.method do
        v when is_binary(v) -> Format.format_method_name(v)
        _ -> nil
      end

    %{tx | method: method}
  end

  defp with_confirmations(%{} = tx, latest_height) when is_integer(latest_height) do
    confirmations =
      case tx.block_number do
        b when is_integer(b) ->
          if latest_height >= b do
            latest_height - b + 1
          else
            0
          end

        _ ->
          nil
      end

    %{tx | confirmations: confirmations}
  end

  defp with_confirmations(%{} = tx, _latest_height), do: tx

  defp address_flags(%{} = tx) do
    from_hash = get_in(tx, [:from, :hash]) || ""

    from_info =
      if valid_eth_address?(from_hash) do
        case Client.get_json_cached("/api/v2/addresses/#{from_hash}", :public) do
          {:ok, json} when is_map(json) -> json
          _ -> nil
        end
      else
        nil
      end

    to_info =
      case tx.to do
        %{hash: to_hash} when is_binary(to_hash) and to_hash != "" ->
          if valid_eth_address?(to_hash) do
            case Client.get_json_cached("/api/v2/addresses/#{to_hash}", :public) do
              {:ok, json} when is_map(json) -> json
              _ -> nil
            end
          else
            nil
          end

        _ ->
          nil
      end

    from_is_verified = truthy?(from_info && from_info["is_verified"])

    from_is_contract_like =
      truthy?(from_info && from_info["is_contract"]) || from_is_verified ||
        is_binary(from_info && from_info["name"])

    to_is_verified = truthy?(to_info && to_info["is_verified"])

    to_is_contract_like =
      truthy?(to_info && to_info["is_contract"]) || to_is_verified ||
        is_binary(to_info && to_info["name"])

    {from_is_contract_like, from_is_verified, to_is_contract_like, to_is_verified}
  end

  defp truthy?(true), do: true
  defp truthy?(_), do: false

  defp derive_tx_display_fields(%{} = tx, skin) do
    fee_eth =
      case tx.fee do
        %{value: v} when is_binary(v) -> Format.format_wei_to_eth_exact(v)
        _ -> nil
      end

    timestamp_relative = if tx.timestamp, do: Format.format_relative_time(tx.timestamp), else: nil

    timestamp_readable =
      case tx.timestamp do
        ts when is_binary(ts) ->
          if skin == :classic do
            Format.format_readable_date_classic(ts)
          else
            Format.format_readable_date(ts)
          end

        _ ->
          nil
      end

    method_id =
      case tx.raw_input do
        input when is_binary(input) and byte_size(input) >= 10 -> binary_part(input, 0, 10)
        _ -> nil
      end

    {fee_eth, timestamp_relative, timestamp_readable, method_id}
  end

  defp gas_fields(nil, _limit), do: {nil, nil}
  defp gas_fields(used, nil) when is_binary(used), do: {used, nil}
  defp gas_fields(_used, nil), do: {nil, nil}

  defp gas_fields(used, limit) when is_binary(used) and is_binary(limit) do
    case {Integer.parse(used), Integer.parse(limit)} do
      {{u, ""}, {l, ""}} when l > 0 ->
        pct = u * 100.0 / l
        {used <> " / " <> limit, :io_lib.format("~.2f", [pct]) |> IO.iodata_to_binary()}

      {{_u, ""}, {0, ""}} ->
        {used, "0"}

      {{_u, ""}, {_l, ""}} ->
        {used, nil}

      _ ->
        {used, nil}
    end
  end

  defp gas_fields(_used, _limit), do: {nil, nil}

  defp parse_u64(v) when is_integer(v) and v >= 0, do: v

  defp parse_u64(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_u64(_), do: nil
end
