defmodule FrontendExWeb.AddressTabsController do
  use FrontendExWeb, :controller

  require Logger

  alias FrontendEx.Blockscout.Client
  alias FrontendEx.Format
  alias FrontendExWeb.AddressHTML
  alias FrontendExWeb.AddressTabsHTML

  @task_timeout_ms 10_000
  @preview_limit 25

  @address_re ~r/\A0x[0-9a-fA-F]{40}\z/
  @digits_re ~r/\A\d+\z/

  def tokens(conn, %{"address" => address}) when is_binary(address) do
    address = normalize_address_param(address)

    cond do
      is_nil(address) ->
        send_address_not_found(conn)

      FrontendExWeb.Skin.current() == :classic ->
        render_tokens(conn, address)

      true ->
        send_not_found(conn)
    end
  end

  def token_transfers(conn, %{"address" => address}) when is_binary(address) do
    address = normalize_address_param(address)

    cond do
      is_nil(address) ->
        send_address_not_found(conn)

      FrontendExWeb.Skin.current() == :classic ->
        render_token_transfers(conn, address)

      true ->
        send_not_found(conn)
    end
  end

  def internal(conn, %{"address" => address}) when is_binary(address) do
    address = normalize_address_param(address)

    cond do
      is_nil(address) ->
        send_address_not_found(conn)

      FrontendExWeb.Skin.current() == :classic ->
        render_internal(conn, address)

      true ->
        send_not_found(conn)
    end
  end

  defp normalize_address_param(address) when is_binary(address) do
    address = String.trim(address)

    if Regex.match?(@address_re, address) do
      String.downcase(address)
    else
      nil
    end
  end

  defp normalize_address_param(_), do: nil

  defp send_address_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Address not found")
  end

  defp send_not_found(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not found")
  end

  defp render_tokens(conn, address) when is_binary(address) do
    safe_empty = {:safe, ""}

    explorer_url = Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

    stats_path = "/api/v2/stats"
    addr_path = "/api/v2/addresses/#{address}"
    tokens_path = "/api/v2/addresses/#{address}/tokens"

    stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
    addr_task = Task.async(fn -> safe_get_json_cached(addr_path, :public) end)
    tokens_task = Task.async(fn -> safe_get_json_cached(tokens_path, :public) end)

    [stats_json, addr_json, tokens_json] =
      await_many_ok(
        [{"stats", stats_task}, {"address", addr_task}, {"tokens", tokens_task}],
        @task_timeout_ms
      )

    if is_nil(addr_json) do
      send_address_not_found(conn)
    else
      {coin_price, gas_price} = derive_coin_gas(stats_json)
      address_info = parse_address(addr_json)

      if String.trim(address_info.hash || "") == "" do
        send_address_not_found(conn)
      else
        token_balances = parse_token_balances(tokens_json)
        token_holdings_count = length(token_balances)

        balance_display = format_balance_display(address_info.coin_balance)
        balance_usd_display = derive_balance_usd_display(address_info.coin_balance, coin_price)

        token_holdings_display =
          if token_holdings_count == 0 do
            "N/A"
          else
            ">$0.00 (#{token_holdings_count} Tokens)"
          end

        tx_count_display = format_tx_count_display(address_info.transactions_count)

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
          address: address_info,
          token_balances: token_balances,
          balance_display: balance_display,
          balance_usd_display: balance_usd_display,
          token_holdings_display: token_holdings_display,
          tx_count_display: tx_count_display,
          coin_price: coin_price,
          gas_price: gas_price
        }

        styles = AddressTabsHTML.classic_tokens_styles(base_assigns)

        render(conn, :classic_tokens_content, %{
          base_assigns
          | page_title: "Address #{address_info.hash} Token Holdings | Sepolia",
            styles: styles
        })
      end
    end
  end

  defp render_token_transfers(conn, address) when is_binary(address) do
    safe_empty = {:safe, ""}

    explorer_url = Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

    stats_path = "/api/v2/stats"
    addr_path = "/api/v2/addresses/#{address}"
    transfers_path = "/api/v2/addresses/#{address}/token-transfers"
    tokens_path = "/api/v2/addresses/#{address}/tokens"

    stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
    addr_task = Task.async(fn -> safe_get_json_cached(addr_path, :public) end)
    transfers_task = Task.async(fn -> safe_get_json_cached(transfers_path, :public) end)
    tokens_task = Task.async(fn -> safe_get_json_cached(tokens_path, :public) end)

    [stats_json, addr_json, transfers_json, tokens_json] =
      await_many_ok(
        [
          {"stats", stats_task},
          {"address", addr_task},
          {"token_transfers", transfers_task},
          {"tokens", tokens_task}
        ],
        @task_timeout_ms
      )

    if is_nil(addr_json) do
      send_address_not_found(conn)
    else
      {coin_price, gas_price} = derive_coin_gas(stats_json)
      address_info = parse_address(addr_json)

      if String.trim(address_info.hash || "") == "" do
        send_address_not_found(conn)
      else
        token_transfers = parse_token_transfers(transfers_json, address)

        token_holdings_count = tokens_json |> parse_token_balances() |> length()

        balance_display = format_balance_display(address_info.coin_balance)
        balance_usd_display = derive_balance_usd_display(address_info.coin_balance, coin_price)

        token_holdings_display =
          if token_holdings_count == 0 do
            "N/A"
          else
            ">$0.00 (#{token_holdings_count} Tokens)"
          end

        tx_count_display = format_tx_count_display(address_info.transactions_count)

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
          address: address_info,
          token_transfers: token_transfers,
          balance_display: balance_display,
          balance_usd_display: balance_usd_display,
          token_holdings_display: token_holdings_display,
          tx_count_display: tx_count_display,
          coin_price: coin_price,
          gas_price: gas_price
        }

        styles = AddressHTML.classic_styles(base_assigns)

        render(conn, :classic_token_transfers_content, %{
          base_assigns
          | page_title: "Address #{address_info.hash} Token Transfers | Sepolia",
            styles: styles
        })
      end
    end
  end

  defp render_internal(conn, address) when is_binary(address) do
    safe_empty = {:safe, ""}

    explorer_url = Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

    stats_path = "/api/v2/stats"
    addr_path = "/api/v2/addresses/#{address}"
    internal_path = "/api/v2/addresses/#{address}/internal-transactions"
    tokens_path = "/api/v2/addresses/#{address}/tokens"

    stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
    addr_task = Task.async(fn -> safe_get_json_cached(addr_path, :public) end)
    internal_task = Task.async(fn -> safe_get_json_cached(internal_path, :public) end)
    tokens_task = Task.async(fn -> safe_get_json_cached(tokens_path, :public) end)

    [stats_json, addr_json, internal_json, tokens_json] =
      await_many_ok(
        [
          {"stats", stats_task},
          {"address", addr_task},
          {"internal", internal_task},
          {"tokens", tokens_task}
        ],
        @task_timeout_ms
      )

    if is_nil(addr_json) do
      send_address_not_found(conn)
    else
      {coin_price, gas_price} = derive_coin_gas(stats_json)
      address_info = parse_address(addr_json)

      if String.trim(address_info.hash || "") == "" do
        send_address_not_found(conn)
      else
        internal_txns = parse_internal_transactions(internal_json)

        token_holdings_count = tokens_json |> parse_token_balances() |> length()

        balance_display = format_balance_display(address_info.coin_balance)
        balance_usd_display = derive_balance_usd_display(address_info.coin_balance, coin_price)

        token_holdings_display =
          if token_holdings_count == 0 do
            "N/A"
          else
            ">$0.00 (#{token_holdings_count} Tokens)"
          end

        tx_count_display = format_tx_count_display(address_info.transactions_count)

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
          address: address_info,
          internal_txns: internal_txns,
          balance_display: balance_display,
          balance_usd_display: balance_usd_display,
          token_holdings_display: token_holdings_display,
          tx_count_display: tx_count_display,
          coin_price: coin_price,
          gas_price: gas_price
        }

        styles = AddressHTML.classic_styles(base_assigns)

        render(conn, :classic_internal_content, %{
          base_assigns
          | page_title: "Address #{address_info.hash} Internal Transactions | Sepolia",
            styles: styles
        })
      end
    end
  end

  defp safe_get_json_cached(path, context) when is_binary(path) do
    try do
      Client.get_json_cached(path, context)
    rescue
      e ->
        {:error, {:exception, e.__struct__, Exception.message(e)}}
    catch
      kind, reason ->
        {:error, {kind, reason}}
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
          Logger.warning("address-tabs: upstream request failed",
            endpoint: label,
            reason: inspect(reason)
          )

          nil

        {:ok, other} ->
          Logger.warning("address-tabs: upstream request returned unexpected result",
            endpoint: label,
            result: inspect(other)
          )

          nil

        {:exit, reason} ->
          Logger.warning("address-tabs: upstream task crashed",
            endpoint: label,
            reason: inspect(reason)
          )

          nil

        nil ->
          Task.shutdown(task, :brutal_kill)

          Logger.warning("address-tabs: upstream request timed out",
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
        v when is_number(v) -> Format.format_one_decimal(v)
        _ -> nil
      end

    {coin_price, gas_price}
  end

  defp derive_coin_gas(_), do: {nil, nil}

  defp parse_address(%{} = json) do
    hash = to_string(json["hash"] || "")

    %{
      hash: hash,
      is_contract: json["is_contract"],
      coin_balance: normalize_opt_string(json["coin_balance"]),
      transactions_count: parse_u64(json["transactions_count"])
    }
  end

  defp parse_address(_),
    do: %{
      hash: "",
      is_contract: nil,
      coin_balance: nil,
      transactions_count: nil
    }

  defp format_balance_display(nil), do: "0 ETH"

  defp format_balance_display(wei_balance) when is_binary(wei_balance) do
    Format.format_wei_to_eth_exact(wei_balance) <> " ETH"
  end

  defp derive_balance_usd_display(nil, _coin_price), do: nil
  defp derive_balance_usd_display(_wei_balance, nil), do: nil

  defp derive_balance_usd_display(wei_balance, coin_price)
       when is_binary(wei_balance) and is_binary(coin_price) do
    with {eth, ""} <- Float.parse(Format.format_wei_to_eth(wei_balance)),
         {cp, ""} <- Float.parse(String.replace(coin_price, ",", "")) do
      usd = eth * cp

      usd_s = :io_lib.format("~.2f", [usd]) |> IO.iodata_to_binary()

      formatted =
        case String.split(usd_s, ".", parts: 2) do
          [int_part, frac_part] -> Format.format_number_with_commas(int_part) <> "." <> frac_part
          [int_part] -> Format.format_number_with_commas(int_part)
        end

      "$" <> formatted
    else
      _ -> nil
    end
  end

  defp derive_balance_usd_display(_wei_balance, _coin_price), do: nil

  defp format_tx_count_display(nil), do: ""

  defp format_tx_count_display(count) when is_integer(count) and count >= 0 do
    Format.format_number_with_commas(Integer.to_string(count))
  end

  defp normalize_opt_string(v) when is_binary(v), do: String.trim(v)
  defp normalize_opt_string(_), do: nil

  defp normalize_id_or_dash(v) when is_binary(v) do
    v = String.trim(v)
    if v == "", do: "-", else: v
  end

  defp normalize_id_or_dash(v) when is_integer(v), do: Integer.to_string(v)
  defp normalize_id_or_dash(_), do: "-"

  defp parse_u64(v) when is_integer(v) and v >= 0, do: v

  defp parse_u64(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_u64(_), do: nil

  defp parse_opt_u8(nil), do: nil
  defp parse_opt_u8(v) when is_integer(v) and v >= 0 and v <= 255, do: v

  defp parse_opt_u8(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} when n >= 0 and n <= 255 -> n
      _ -> nil
    end
  end

  defp parse_opt_u8(_), do: nil

  defp parse_token_balances(nil), do: []

  defp parse_token_balances(%{} = tokens_json) do
    items =
      case tokens_json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    Enum.flat_map(items, fn
      %{"token" => %{} = token, "value" => value} ->
        name =
          cond do
            is_binary(token["name"]) -> token["name"]
            is_binary(token["address"]) -> token["address"]
            is_binary(token["address_hash"]) -> token["address_hash"]
            true -> "-"
          end

        symbol =
          cond do
            is_binary(token["symbol"]) -> token["symbol"]
            true -> "-"
          end

        decimals = parse_opt_u8(token["decimals"]) || 0

        value_s =
          cond do
            is_binary(value) -> value
            is_integer(value) -> Integer.to_string(value)
            # Blockscout token unit values should be integers; treat floats as invalid to avoid
            # incorrect decimal formatting (e.g. "1.0").
            is_float(value) -> "0"
            true -> "0"
          end
          |> String.trim()

        value_s =
          if Regex.match?(@digits_re, value_s) do
            value_s
          else
            "0"
          end

        balance =
          value_s
          |> Format.unit_to_decimal_value(decimals)
          |> Format.format_decimal_with_commas()

        token_address =
          cond do
            is_binary(token["address"]) -> token["address"]
            is_binary(token["address_hash"]) -> token["address_hash"]
            true -> nil
          end

        token_icon_url =
          case token["icon_url"] do
            v when is_binary(v) -> v
            _ -> nil
          end

        [
          %{
            name: name,
            symbol: symbol,
            balance: balance,
            token_address: token_address,
            token_icon_url: token_icon_url
          }
        ]

      _ ->
        []
    end)
  end

  defp parse_token_transfers(nil, _address), do: []

  defp parse_token_transfers(%{} = json, address) when is_binary(address) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    items
    |> Enum.map(&build_token_transfer_row(&1, address))
    |> Enum.reject(&is_nil/1)
    |> Enum.take(@preview_limit)
  end

  defp parse_token_transfers(_other, _address), do: []

  defp build_token_transfer_row(%{} = transfer, address) when is_binary(address) do
    tx_hash = normalize_id_or_dash(transfer["transaction_hash"])

    method =
      transfer["method"]
      |> case do
        v when is_binary(v) -> v
        _ -> "Transfer"
      end
      |> Format.format_method_name()

    block_number = normalize_id_or_dash(transfer["block_number"])

    age =
      case transfer["timestamp"] do
        v when is_binary(v) -> Format.format_relative_time(v)
        _ -> "-"
      end

    from_hash = normalize_id_or_dash(get_in(transfer, ["from", "hash"]))

    to_hash = normalize_id_or_dash(get_in(transfer, ["to", "hash"]))

    address_lc = String.downcase(address)

    is_out =
      if from_hash == "-" do
        nil
      else
        String.downcase(from_hash) == address_lc
      end

    amount = format_token_amount(get_in(transfer, ["total"]), get_in(transfer, ["token"]))

    {token_label, token_symbol} = format_transfer_token_label(get_in(transfer, ["token"]))

    token_address =
      case get_in(transfer, ["token", "address"]) do
        v when is_binary(v) -> v
        _ -> get_in(transfer, ["token", "address_hash"])
      end
      |> case do
        v when is_binary(v) -> v
        _ -> nil
      end

    token_icon_url =
      case get_in(transfer, ["token", "icon_url"]) do
        v when is_binary(v) -> v
        _ -> nil
      end

    tx_path = if tx_hash == "-", do: "#", else: "/tx/#{tx_hash}"
    block_path = if block_number == "-", do: "#", else: "/block/#{block_number}"
    from_path = if from_hash == "-", do: "#", else: "/address/#{from_hash}"
    to_path = if to_hash == "-", do: "#", else: "/address/#{to_hash}"

    tx_copy = if tx_hash == "-", do: "", else: tx_hash
    from_copy = if from_hash == "-", do: "", else: from_hash
    to_copy = if to_hash == "-", do: "", else: to_hash

    %{
      tx_hash: tx_hash,
      tx_path: tx_path,
      tx_copy: tx_copy,
      method: method,
      block_number: block_number,
      block_path: block_path,
      age: age,
      from_hash: from_hash,
      from_path: from_path,
      from_copy: from_copy,
      to_hash: to_hash,
      to_path: to_path,
      to_copy: to_copy,
      is_out: is_out,
      amount: amount,
      token_label: token_label,
      token_symbol: token_symbol,
      token_address: token_address,
      token_icon_url: token_icon_url
    }
  end

  defp build_token_transfer_row(_other, _address), do: nil

  defp format_transfer_token_label(%{} = token) do
    token_name =
      cond do
        is_binary(token["name"]) -> token["name"]
        is_binary(token["symbol"]) -> token["symbol"]
        true -> "-"
      end

    token_label =
      if String.trim(token_name) == "" do
        "ERC-20"
      else
        "ERC-20: " <> token_name
      end

    token_symbol =
      case token["symbol"] do
        v when is_binary(v) ->
          if String.trim(v) == "", do: nil, else: v

        _ ->
          nil
      end

    {token_label, token_symbol}
  end

  defp format_transfer_token_label(_), do: {"ERC-20", nil}

  defp format_token_amount(total, token) when is_map(total) and is_map(token) do
    decimals = parse_opt_u8(token["decimals"]) || parse_opt_u8(total["decimals"]) || 0

    value =
      case total["value"] do
        v when is_binary(v) -> v
        _ -> "0"
      end

    value
    |> Format.unit_to_decimal_value(decimals)
    |> Format.format_decimal_with_commas()
  end

  defp format_token_amount(_total, _token), do: "0"

  defp parse_internal_transactions(nil), do: []

  defp parse_internal_transactions(%{} = json) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    items
    |> Enum.sort_by(
      fn itx ->
        bn = parse_int_or(get_in(itx, ["block_number"]), 0)
        idx = parse_int_or(get_in(itx, ["index"]), 0)
        {bn, idx}
      end,
      :desc
    )
    |> Enum.take(@preview_limit)
    |> Enum.map(&build_internal_row/1)
    |> Enum.reject(&is_nil/1)
  end

  defp parse_internal_transactions(_other), do: []

  defp build_internal_row(%{} = itx) do
    tx_type =
      case itx["type"] do
        v when is_binary(v) -> String.upcase(v)
        _ -> "-"
      end

    parent_tx_hash = normalize_id_or_dash(itx["transaction_hash"])

    method =
      case itx["value"] do
        v when is_binary(v) ->
          raw = v |> String.trim() |> String.trim_leading("0")
          if raw == "" or raw == "0", do: "Call", else: "Transfer"

        _ ->
          "Call"
      end

    block_number = normalize_id_or_dash(itx["block_number"])

    age =
      case itx["timestamp"] do
        v when is_binary(v) -> Format.format_relative_time(v)
        _ -> "-"
      end

    from_hash = normalize_id_or_dash(get_in(itx, ["from", "hash"]))

    to_hash =
      cond do
        is_binary(get_in(itx, ["to", "hash"])) ->
          normalize_id_or_dash(get_in(itx, ["to", "hash"]))

        is_binary(get_in(itx, ["created_contract", "hash"])) ->
          normalize_id_or_dash(get_in(itx, ["created_contract", "hash"]))

        true ->
          "-"
      end

    amount = format_internal_amount(itx["value"])

    parent_tx_path = if parent_tx_hash == "-", do: "#", else: "/tx/#{parent_tx_hash}"
    block_path = if block_number == "-", do: "#", else: "/block/#{block_number}"
    from_path = if from_hash == "-", do: "#", else: "/address/#{from_hash}"
    to_path = if to_hash == "-", do: "#", else: "/address/#{to_hash}"

    parent_tx_copy = if parent_tx_hash == "-", do: "", else: parent_tx_hash
    from_copy = if from_hash == "-", do: "", else: from_hash
    to_copy = if to_hash == "-", do: "", else: to_hash

    %{
      tx_type: tx_type,
      parent_tx_hash: parent_tx_hash,
      parent_tx_path: parent_tx_path,
      parent_tx_copy: parent_tx_copy,
      method: method,
      block_number: block_number,
      block_path: block_path,
      age: age,
      from_hash: from_hash,
      from_path: from_path,
      from_copy: from_copy,
      to_hash: to_hash,
      to_path: to_path,
      to_copy: to_copy,
      amount: amount
    }
  end

  defp build_internal_row(_), do: nil

  defp format_internal_amount(nil), do: "0 ETH"

  defp format_internal_amount(wei) when is_binary(wei) do
    raw = wei |> String.trim() |> String.trim_leading("0")

    if raw == "" or raw == "0" do
      "0 ETH"
    else
      Format.format_wei_to_eth_exact(raw) <> " ETH"
    end
  end

  defp format_internal_amount(_), do: "0 ETH"

  defp parse_int_or(nil, fallback), do: fallback
  defp parse_int_or(v, _fallback) when is_integer(v), do: v

  defp parse_int_or(v, fallback) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} -> n
      _ -> fallback
    end
  end

  defp parse_int_or(_v, fallback), do: fallback
end
