defmodule FrontendExWeb.TokenController do
  use FrontendExWeb, :controller

  alias FrontendEx.Blockscout.Client
  alias FrontendEx.Blockscout.Cursor
  alias FrontendEx.Format
  alias FrontendExWeb.BlockHTML

  @task_timeout_ms 10_000
  @max_cursor_len 200
  @max_items_count 50

  def show(conn, %{"address" => address} = params) when is_binary(address) and is_map(params) do
    address = String.trim(address)

    if not eth_address?(address) do
      conn |> put_resp_content_type("text/plain") |> send_resp(404, "Token not found")
    else
      cursor_query = cursor_query_param(params)

      skin = FrontendExWeb.Skin.current()
      is_first_page = is_nil(cursor_query)

      stats_path = "/api/v2/stats"
      token_path = "/api/v2/tokens/#{address}"
      transfers_path = transfers_path(address, cursor_query)

      stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
      token_task = Task.async(fn -> safe_get_json_cached(token_path, :public) end)
      transfers_task = Task.async(fn -> safe_get_json_cached(transfers_path, :public) end)

      [stats_json, token_json, transfers_json] =
        await_many_ok(
          [{"stats", stats_task}, {"token", token_task}, {"transfers", transfers_task}],
          "token",
          @task_timeout_ms
        )

      if is_nil(token_json) do
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Token not found")
      else
        {coin_price, gas_price} = derive_coin_gas(stats_json)
        token = parse_token(token_json, address)
        header = build_token_header(token, address)

        {transfers, next_cursor} = parse_transfers_response(transfers_json)

        page_label =
          if is_first_page do
            "Latest"
          else
            "Older"
          end

        base_assigns =
          base_assigns(%{
            token: token,
            token_name: header.token_name,
            token_symbol: header.token_symbol_display,
            token_type: header.token_type,
            token_title: header.token_title,
            avatar_letter: header.avatar_letter,
            token_address: header.token_address,
            total_supply_display: header.total_supply_display,
            holders_display: header.holders_display,
            total_transfers_display: "N/A",
            volume_24h_display: header.volume_24h_display,
            price_display: header.price_display,
            market_cap_display: header.market_cap_display,
            transfers: transfers,
            page_label: page_label,
            is_first_page: is_first_page,
            next_cursor: next_cursor,
            coin_price: coin_price,
            gas_price: gas_price
          })

        case skin do
          :classic ->
            render(conn, :classic_content, %{
              base_assigns
              | page_title: header.token_title,
                nav_tokens: "active"
            })

          :s53627 ->
            topbar = BlockHTML.s53627_topbar(base_assigns)

            render(conn, :s53627_content, %{
              base_assigns
              | page_title: "Token #{header.token_name} | Explorer",
                topbar: topbar
            })

          _ ->
            render(conn, :classic_content, %{
              base_assigns
              | page_title: header.token_title,
                nav_tokens: "active"
            })
        end
      end
    end
  end

  def holders(conn, %{"address" => address} = params)
      when is_binary(address) and is_map(params) do
    address = String.trim(address)

    if not eth_address?(address) do
      conn |> put_resp_content_type("text/plain") |> send_resp(404, "Token not found")
    else
      cursor_query = cursor_query_param(params)

      skin = FrontendExWeb.Skin.current()
      is_first_page = is_nil(cursor_query)

      stats_path = "/api/v2/stats"
      token_path = "/api/v2/tokens/#{address}"
      holders_path = holders_path(address, cursor_query)

      stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
      token_task = Task.async(fn -> safe_get_json_cached(token_path, :public) end)
      holders_task = Task.async(fn -> safe_get_json_cached(holders_path, :public) end)

      [stats_json, token_json, holders_json] =
        await_many_ok(
          [{"stats", stats_task}, {"token", token_task}, {"holders", holders_task}],
          "token",
          @task_timeout_ms
        )

      if is_nil(token_json) do
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "Token not found")
      else
        {coin_price, gas_price} = derive_coin_gas(stats_json)
        token = parse_token(token_json, address)
        header = build_token_header(token, address)

        {holders, next_cursor} = parse_holders_response(holders_json, token)

        page_label =
          if is_first_page do
            "Top"
          else
            "More"
          end

        base_assigns =
          base_assigns(%{
            token: token,
            token_name: header.token_name,
            token_symbol: header.token_symbol_display,
            token_type: header.token_type,
            token_title: header.token_title,
            avatar_letter: header.avatar_letter,
            token_address: header.token_address,
            total_supply_display: header.total_supply_display,
            holders_display: header.holders_display,
            total_transfers_display: "N/A",
            volume_24h_display: header.volume_24h_display,
            price_display: header.price_display,
            market_cap_display: header.market_cap_display,
            holders: holders,
            page_label: page_label,
            is_first_page: is_first_page,
            next_cursor: next_cursor,
            coin_price: coin_price,
            gas_price: gas_price
          })

        case skin do
          :classic ->
            render(conn, :classic_holders_content, %{
              base_assigns
              | page_title: header.token_title,
                nav_tokens: "active"
            })

          :s53627 ->
            topbar = BlockHTML.s53627_topbar(base_assigns)

            render(conn, :s53627_holders_content, %{
              base_assigns
              | page_title: "Token #{header.token_name} | Explorer",
                topbar: topbar
            })

          _ ->
            render(conn, :classic_holders_content, %{
              base_assigns
              | page_title: header.token_title,
                nav_tokens: "active"
            })
        end
      end
    end
  end

  defp cursor_query_param(params) when is_map(params) do
    case Map.get(params, "cursor") do
      v when is_binary(v) ->
        v = String.trim(v)

        cond do
          v == "" ->
            nil

          byte_size(v) > @max_cursor_len ->
            nil

          true ->
            sanitize_cursor_query(v)
        end

      _ ->
        nil
    end
  end

  defp transfers_path(address, nil) when is_binary(address) do
    "/api/v2/tokens/#{address}/transfers"
  end

  defp transfers_path(address, cursor_query)
       when is_binary(address) and is_binary(cursor_query) do
    "/api/v2/tokens/#{address}/transfers?" <> cursor_query
  end

  defp holders_path(address, nil) when is_binary(address) do
    "/api/v2/tokens/#{address}/holders"
  end

  defp holders_path(address, cursor_query) when is_binary(address) and is_binary(cursor_query) do
    "/api/v2/tokens/#{address}/holders?" <> cursor_query
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

  # Parse cursor as a query string and rebuild only the safe subset of keys.
  # This prevents cursor-based query injection and caps page size.
  defp sanitize_cursor_query(cursor_query) when is_binary(cursor_query) do
    cursor_query = String.trim(cursor_query)

    decoded =
      try do
        URI.decode_query(cursor_query)
      rescue
        ArgumentError -> %{}
      end

    index = parse_nonneg_int(Map.get(decoded, "index"))

    items_count =
      decoded
      |> Map.get("items_count")
      |> parse_nonneg_int()
      |> clamp_items_count()

    parts =
      [{"index", index}, {"items_count", items_count}]
      |> Enum.flat_map(fn
        {_k, nil} -> []
        {k, v} -> [{k, v}]
      end)

    case parts do
      [] -> nil
      _ -> URI.encode_query(parts)
    end
  end

  defp sanitize_cursor_query(_), do: nil

  defp clamp_items_count(nil), do: nil

  defp clamp_items_count(n) when is_integer(n) and n >= 0 do
    min(n, @max_items_count)
  end

  defp parse_nonneg_int(nil), do: nil
  defp parse_nonneg_int(v) when is_integer(v) and v >= 0, do: v

  defp parse_nonneg_int(v) when is_binary(v) do
    v = String.trim(v)

    if v == "" do
      nil
    else
      case Integer.parse(v) do
        {n, ""} when n >= 0 -> n
        _ -> nil
      end
    end
  end

  defp parse_nonneg_int(_), do: nil

  defp parse_token(nil, address) when is_binary(address) do
    %{
      address_hash: address,
      name: nil,
      symbol: nil,
      decimals: nil,
      icon_url: nil,
      holders_count: nil,
      total_supply: nil,
      token_type: nil,
      exchange_rate: nil,
      circulating_market_cap: nil,
      volume_24h: nil
    }
  end

  defp parse_token(%{} = json, address) when is_binary(address) do
    %{
      address_hash: string_or(json["address_hash"], address),
      name: string_or_nil(json["name"]),
      symbol: string_or_nil(json["symbol"]),
      decimals: parse_opt_u8(json["decimals"]),
      icon_url: string_or_nil(json["icon_url"]),
      holders_count: string_or_nil(json["holders_count"]),
      total_supply: string_or_nil(json["total_supply"]),
      token_type: string_or_nil(json["type"]),
      exchange_rate: string_or_nil(json["exchange_rate"]),
      circulating_market_cap: string_or_nil(json["circulating_market_cap"]),
      volume_24h: string_or_nil(json["volume_24h"])
    }
  end

  defp parse_token(_other, address) when is_binary(address), do: parse_token(nil, address)

  defp parse_transfers_response(nil), do: {[], nil}

  defp parse_transfers_response(%{} = json) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    next_cursor =
      case Map.get(json, "next_page_params") do
        nil -> nil
        other -> Cursor.next_page_params_query(other)
      end

    transfers =
      items
      |> Enum.flat_map(fn
        %{} = transfer -> [display_transfer(transfer)]
        _ -> []
      end)

    {transfers, next_cursor}
  end

  defp parse_transfers_response(_), do: {[], nil}

  defp display_transfer(%{} = transfer) do
    tx_hash =
      case transfer["transaction_hash"] do
        v when is_binary(v) -> v
        _ -> "-"
      end

    method =
      case transfer["method"] do
        v when is_binary(v) ->
          v = String.trim(v)

          if v == "" do
            "Transfer"
          else
            Format.format_method_name(v)
          end

        _ ->
          "Transfer"
      end

    block_number =
      case transfer["block_number"] do
        v when is_integer(v) -> v
        v when is_binary(v) -> parse_int_or(v, nil)
        _ -> nil
      end

    age =
      case transfer["timestamp"] do
        v when is_binary(v) -> Format.format_relative_time(v)
        _ -> "-"
      end

    from_hash = string_or_nil(get_in(transfer, ["from", "hash"])) || ""
    to_hash = string_or_nil(get_in(transfer, ["to", "hash"])) || ""

    amount = format_transfer_amount(transfer)
    token_id = format_transfer_token_id(get_in(transfer, ["total", "token_id"]))

    %{
      tx_hash: tx_hash,
      method: method,
      block_number: block_number,
      age: age,
      from_hash: from_hash,
      to_hash: to_hash,
      amount: amount,
      token_id: token_id
    }
  end

  defp format_transfer_token_id(v) when is_binary(v) do
    v = String.trim(v)
    if v == "", do: "-", else: "#" <> v
  end

  defp format_transfer_token_id(_), do: "-"

  defp format_transfer_amount(%{} = transfer) do
    decimals =
      parse_opt_u8(get_in(transfer, ["token", "decimals"])) ||
        parse_opt_u8(get_in(transfer, ["total", "decimals"])) || 0

    value =
      case get_in(transfer, ["total", "value"]) do
        v when is_binary(v) -> v
        _ -> "0"
      end

    value
    |> Format.unit_to_decimal_value(decimals)
    |> Format.format_decimal_with_commas()
  end

  defp parse_holders_response(nil, _token), do: {[], nil}

  defp parse_holders_response(%{} = json, %{} = token) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    next_cursor =
      case Map.get(json, "next_page_params") do
        nil -> nil
        other -> Cursor.next_page_params_query(other)
      end

    # Match Rust behavior: if holder item shape is unexpected, treat response as error and show none.
    holders =
      case Enum.all?(items, &valid_holder_item?/1) do
        true ->
          Enum.with_index(items, 1)
          |> Enum.map(fn {%{} = holder, rank} ->
            build_holder_row(holder, rank, token)
          end)

        false ->
          []
      end

    next_cursor = if holders == [], do: nil, else: next_cursor

    {holders, next_cursor}
  end

  defp parse_holders_response(_other, _token), do: {[], nil}

  defp valid_holder_item?(%{} = holder) do
    match?(%{"hash" => h} when is_binary(h), holder["address"]) and is_binary(holder["value"])
  end

  defp valid_holder_item?(_), do: false

  defp build_holder_row(%{} = holder, rank, %{} = token) when is_integer(rank) do
    address_hash = string_or_nil(get_in(holder, ["address", "hash"])) || ""

    amount =
      holder["value"]
      |> Format.unit_to_decimal_value(token.decimals || 0)
      |> Format.format_decimal_with_commas()
      |> append_symbol(token.symbol)

    percentage = format_holder_percentage(token.total_supply, holder["value"])

    %{
      rank: rank,
      address_hash: address_hash,
      amount: amount,
      percentage: percentage
    }
  end

  defp append_symbol(amount, nil), do: amount
  defp append_symbol(amount, symbol) when is_binary(symbol), do: amount <> " " <> symbol
  defp append_symbol(amount, _), do: amount

  defp format_holder_percentage(nil, _holder_value), do: "-"

  defp format_holder_percentage(total_supply, holder_value)
       when is_binary(total_supply) and is_binary(holder_value) do
    total_raw =
      total_supply
      |> String.trim()
      |> String.trim_leading("0")
      |> case do
        "" -> "0"
        v -> v
      end

    holder_raw =
      holder_value
      |> String.trim()
      |> String.trim_leading("0")
      |> case do
        "" -> "0"
        v -> v
      end

    with {total, ""} <- Float.parse(total_raw),
         true <- total > 0.0,
         {value, ""} <- Float.parse(holder_raw) do
      pct = value / total * 100.0

      cond do
        pct > 0.0 and pct < 0.0001 -> "<0.0001%"
        true -> :io_lib.format("~.4f%", [pct]) |> IO.iodata_to_binary()
      end
    else
      _ -> "-"
    end
  end

  defp format_holder_percentage(_total_supply, _holder_value), do: "-"

  defp build_token_header(%{} = token, address) when is_binary(address) do
    token_symbol = normalize_token_symbol(token.symbol)
    token_name = normalize_token_name(token.name, token_symbol)

    token_symbol_display =
      if has_token_name?(token.name) do
        token_symbol
      else
        nil
      end

    token_type = normalize_token_type(token.token_type)
    avatar_letter = token_avatar_letter(token_name, token_symbol)
    token_address = string_or_nil(token.address_hash) || address

    token_title =
      case token_symbol_display do
        s when is_binary(s) -> "Token #{token_name} (#{s}) | Sepolia"
        _ -> "Token #{token_name} | Sepolia"
      end

    total_supply_display = format_total_supply(token.total_supply, token.decimals, token_symbol)
    holders_display = format_holders_count(token.holders_count)
    volume_24h_display = format_usd_value(token.volume_24h)
    price_display = format_usd_value(token.exchange_rate)
    market_cap_display = format_usd_value(token.circulating_market_cap)

    %{
      token_name: token_name,
      token_symbol: token_symbol,
      token_symbol_display: token_symbol_display,
      token_type: token_type,
      token_title: token_title,
      avatar_letter: avatar_letter,
      token_address: token_address,
      total_supply_display: total_supply_display,
      holders_display: holders_display,
      volume_24h_display: volume_24h_display,
      price_display: price_display,
      market_cap_display: market_cap_display
    }
  end

  defp has_token_name?(nil), do: false

  defp has_token_name?(name) when is_binary(name) do
    name |> String.trim() |> then(&(&1 != ""))
  end

  defp has_token_name?(_), do: false

  defp normalize_token_name(name, symbol) do
    name =
      name
      |> string_or_nil()
      |> normalize_present()

    symbol =
      symbol
      |> string_or_nil()
      |> normalize_present()

    cond do
      is_binary(name) -> name
      is_binary(symbol) -> symbol
      true -> "Unknown Token"
    end
  end

  defp normalize_token_symbol(symbol) do
    symbol
    |> string_or_nil()
    |> normalize_present()
  end

  defp normalize_token_type(token_type) do
    token_type
    |> string_or_nil()
    |> normalize_present()
    |> case do
      v when is_binary(v) -> v
      _ -> "Token"
    end
  end

  defp normalize_present(nil), do: nil

  defp normalize_present(v) when is_binary(v) do
    v = String.trim(v)
    if v == "", do: nil, else: v
  end

  defp normalize_present(_), do: nil

  defp token_avatar_letter(token_name, token_symbol) when is_binary(token_name) do
    source =
      case token_symbol do
        s when is_binary(s) ->
          s = String.trim(s)
          if s == "", do: token_name, else: s

        _ ->
          token_name
      end

    source
    |> String.to_charlist()
    |> Enum.find(fn c ->
      (c >= ?0 and c <= ?9) or (c >= ?A and c <= ?Z) or (c >= ?a and c <= ?z)
    end)
    |> case do
      nil -> "T"
      c when c >= ?a and c <= ?z -> <<c - 32>>
      c -> <<c>>
    end
  end

  defp token_avatar_letter(_token_name, token_symbol) when is_binary(token_symbol) do
    token_avatar_letter(token_symbol, nil)
  end

  defp token_avatar_letter(_token_name, _token_symbol), do: "T"

  defp format_holders_count(nil), do: "N/A"

  defp format_holders_count(v) when is_binary(v) do
    Format.format_number_with_commas(v)
  end

  defp format_holders_count(_), do: "N/A"

  defp format_total_supply(nil, _decimals, _token_symbol), do: "N/A"

  defp format_total_supply(total_supply, decimals, token_symbol) when is_binary(total_supply) do
    raw = total_supply |> String.trim() |> normalize_present()

    if is_nil(raw) do
      "N/A"
    else
      decimals = decimals || 0

      formatted =
        raw
        |> Format.unit_to_decimal_value(decimals)
        |> Format.format_decimal_with_commas()

      append_symbol(formatted, token_symbol)
    end
  end

  defp format_total_supply(_total_supply, _decimals, _token_symbol), do: "N/A"

  defp format_usd_value(nil), do: "N/A"

  defp format_usd_value(v) when is_binary(v) do
    raw = v |> String.trim() |> normalize_present()

    if is_nil(raw) do
      "N/A"
    else
      "$" <> Format.format_price_with_commas(raw)
    end
  end

  defp format_usd_value(_), do: "N/A"

  defp string_or_nil(nil), do: nil
  defp string_or_nil(v) when is_binary(v), do: v
  defp string_or_nil(v) when is_integer(v), do: Integer.to_string(v)
  defp string_or_nil(v) when is_float(v), do: to_string(v)
  defp string_or_nil(_), do: nil

  defp string_or(nil, fallback), do: fallback
  defp string_or(v, _fallback) when is_binary(v), do: v
  defp string_or(v, fallback) when is_integer(v), do: Integer.to_string(v) || fallback
  defp string_or(_v, fallback), do: fallback

  defp parse_opt_u8(nil), do: nil

  defp parse_opt_u8(v) when is_integer(v) and v >= 0 and v <= 255, do: v

  defp parse_opt_u8(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} when n >= 0 and n <= 255 -> n
      _ -> nil
    end
  end

  defp parse_opt_u8(_), do: nil
end
