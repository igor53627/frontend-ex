defmodule FrontendExWeb.NftController do
  use FrontendExWeb, :controller

  require Logger

  alias FrontendEx.Blockscout.Client
  alias FrontendEx.Blockscout.Cursor
  alias FrontendEx.Format
  alias FrontendExWeb.BlockHTML
  alias FrontendExWeb.NftHTML

  @page_size_options [10, 25, 50, 100]
  @default_page_size 50
  @default_export_page_size 100

  @nft_types "ERC-721,ERC-1155"
  @zero_address "0x0000000000000000000000000000000000000000"

  @export_limit 1000
  @max_pages 50

  def transfers(conn, params) when is_map(params) do
    render_transfers(conn, params)
  end

  def latest_mints(conn, params) when is_map(params) do
    render_latest_mints(conn, params)
  end

  def latest_mints_csv(conn, params) when is_map(params) do
    page_size = normalize_export_page_size(params)
    filter = resolve_export_filter(params)
    cursor_query = normalize_cursor_param(Map.get(params, "cursor"))

    mints = export_collect_mints(page_size, cursor_query, filter)
    csv = build_mints_csv(mints)

    conn
    |> put_resp_content_type("text/csv", "utf-8")
    |> put_resp_header("content-disposition", "attachment; filename=\"nft-latest-mints.csv\"")
    |> send_resp(200, csv)
  end

  defp render_transfers(conn, params) when is_map(params) do
    skin = FrontendExWeb.Skin.current()

    safe_empty = safe_empty()

    explorer_url = explorer_url()

    page_size = normalize_page_size(params)
    cursor_query = normalize_cursor_param(Map.get(params, "cursor"))
    is_first_page = is_nil(cursor_query)

    stats_path = "/api/v2/stats"
    token_transfers_path = token_transfers_path(page_size, cursor_query, @nft_types)

    stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
    transfers_task = Task.async(fn -> safe_get_json_cached(token_transfers_path, :public) end)

    [stats_json, transfers_json] =
      await_many_ok([{stats_path, stats_task}, {token_transfers_path, transfers_task}], "nfts")

    {coin_price, gas_price} = derive_coin_gas(stats_json)
    {transfers, next_cursor} = parse_transfers_response(transfers_json)

    page_label = if is_first_page, do: "Latest", else: "Older"

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
      transfers: transfers,
      coin_price: coin_price,
      gas_price: gas_price,
      page_size: page_size,
      page_size_options: page_size_options,
      page_label: page_label,
      is_first_page: is_first_page,
      next_cursor: next_cursor
    }

    case skin do
      :classic ->
        styles = NftHTML.classic_transfers_styles(base_assigns)

        render(conn, :classic_transfers_content, %{
          base_assigns
          | page_title: "NFT Transfers | Sepolia",
            nav_nfts: "active",
            styles: styles
        })

      :s53627 ->
        topbar = BlockHTML.s53627_topbar(base_assigns)

        render(conn, :s53627_transfers_content, %{
          base_assigns
          | page_title: "NFT Transfers | Explorer",
            topbar: topbar
        })
    end
  end

  defp render_latest_mints(conn, params) when is_map(params) do
    skin = FrontendExWeb.Skin.current()

    safe_empty = safe_empty()

    explorer_url = explorer_url()

    page_size = normalize_page_size(params)
    cursor_query = normalize_cursor_param(Map.get(params, "cursor"))
    is_first_page = is_nil(cursor_query)

    stats_path = "/api/v2/stats"
    token_transfers_path = token_transfers_path(page_size, cursor_query, @nft_types)

    stats_task = Task.async(fn -> safe_get_json_cached(stats_path, :public) end)
    transfers_task = Task.async(fn -> safe_get_json_cached(token_transfers_path, :public) end)

    [stats_json, transfers_json] =
      await_many_ok([{stats_path, stats_task}, {token_transfers_path, transfers_task}], "nfts")

    {coin_price, gas_price} = derive_coin_gas(stats_json)
    {mints, next_cursor} = parse_latest_mints_response(transfers_json)

    page_label = if is_first_page, do: "Latest", else: "Older"

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
      mints: mints,
      coin_price: coin_price,
      gas_price: gas_price,
      page_size: page_size,
      page_size_options: page_size_options,
      page_label: page_label,
      is_first_page: is_first_page,
      next_cursor: next_cursor
    }

    case skin do
      :classic ->
        styles = NftHTML.classic_latest_mints_styles(base_assigns)

        render(conn, :classic_latest_mints_content, %{
          base_assigns
          | page_title: "NFT Latest Mints | Sepolia",
            nav_nfts: "active",
            styles: styles
        })

      :s53627 ->
        topbar = BlockHTML.s53627_topbar(base_assigns)

        render(conn, :s53627_latest_mints_content, %{
          base_assigns
          | page_title: "NFT Latest Mints | Explorer",
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

  defp normalize_export_page_size(params) when is_map(params) do
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
        _ -> @default_export_page_size
      end

    if value in @page_size_options, do: value, else: @default_export_page_size
  end

  defp normalize_cursor_param(nil), do: nil

  defp normalize_cursor_param(value) when is_binary(value) do
    value = String.trim(value)
    if value == "", do: nil, else: value
  end

  defp normalize_cursor_param(_), do: nil

  defp token_transfers_path(page_size, nil, token_types)
       when is_integer(page_size) and is_binary(token_types) do
    encoded_types = URI.encode(token_types, &URI.char_unreserved?/1)
    "/api/v2/token-transfers?items_count=#{page_size}&type=#{encoded_types}"
  end

  defp token_transfers_path(page_size, cursor_query, token_types)
       when is_integer(page_size) and is_binary(cursor_query) and is_binary(token_types) do
    # Always use server-controlled items_count to prevent cursor override.
    query = "items_count=#{page_size}"

    filtered_cursor_parts =
      cursor_query
      |> String.split("&", trim: true)
      |> Enum.reject(&String.starts_with?(&1, "items_count="))
      |> Enum.reject(&String.starts_with?(&1, "type="))

    query =
      case filtered_cursor_parts do
        [] -> query
        parts -> query <> "&" <> Enum.join(parts, "&")
      end

    # Always enforce the NFT type filter (cursor must not override it).
    encoded_types = URI.encode(token_types, &URI.char_unreserved?/1)
    query = query <> "&type=" <> encoded_types

    "/api/v2/token-transfers?" <> query
  end

  defp safe_get_json_cached(path, context) when is_binary(path) do
    try do
      Client.get_json_cached(path, context)
    rescue
      e ->
        {:error, {:transport, {:task_crashed, e}}}
    catch
      :exit, reason ->
        {:error, {:transport, {:task_exit, reason}}}

      kind, reason ->
        {:error, {:transport, {kind, reason}}}
    end
  end

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
        other -> Cursor.encode_next_page_params(other)
      end

    transfers =
      items
      |> Enum.flat_map(fn
        %{} = transfer ->
          case build_transfer_display(transfer) do
            nil -> []
            other -> [other]
          end

        _ ->
          []
      end)

    {transfers, next_cursor}
  end

  defp parse_transfers_response(_), do: {[], nil}

  defp parse_latest_mints_response(nil), do: {[], nil}

  defp parse_latest_mints_response(%{} = json) do
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

    mints =
      items
      |> Enum.flat_map(fn
        %{} = transfer ->
          case build_mint_display(transfer) do
            nil -> []
            other -> [other]
          end

        _ ->
          []
      end)

    {mints, next_cursor}
  end

  defp parse_latest_mints_response(_), do: {[], nil}

  defp build_transfer_display(%{} = transfer) do
    token_type = extract_token_type(transfer)

    if nft_transfer?(transfer, token_type) do
      token_id =
        case get_in(transfer, ["total", "token_id"]) do
          v when is_binary(v) ->
            v = String.trim(v)
            if v == "", do: nil, else: v

          _ ->
            nil
        end

      {collection_name, collection_is_address} = resolve_collection_name(transfer)

      item_title = build_item_title(collection_name, collection_is_address, token_id)
      item_title_is_address = collection_is_address and is_nil(token_id)

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

      age =
        case transfer["timestamp"] do
          v when is_binary(v) -> Format.format_relative_time(v)
          _ -> "-"
        end

      %{
        tx_hash: string_or(transfer["transaction_hash"], "-"),
        method: method,
        block_number: parse_u64(transfer["block_number"]),
        age: age,
        from_hash: string_or(get_in(transfer, ["from", "hash"]), ""),
        to_hash: string_or(get_in(transfer, ["to", "hash"]), ""),
        token_type: normalize_token_type(token_type),
        item_title: item_title,
        item_title_is_address: item_title_is_address,
        item_subtitle: collection_name,
        item_subtitle_is_address: collection_is_address,
        token_address: token_address(transfer),
        token_icon_url: string_or_nil(get_in(transfer, ["token", "icon_url"]))
      }
    else
      nil
    end
  end

  defp build_mint_display(%{} = transfer) do
    token_type = extract_token_type(transfer)

    if nft_transfer?(transfer, token_type) and mint_transfer?(transfer) do
      {collection_name, collection_is_address} = resolve_collection_name(transfer)

      token_id =
        case get_in(transfer, ["total", "token_id"]) do
          v when is_binary(v) ->
            v = String.trim(v)
            if v == "", do: nil, else: v

          _ ->
            nil
        end

      item_title = build_item_title(collection_name, collection_is_address, token_id)

      timestamp =
        case transfer["timestamp"] do
          v when is_binary(v) -> v
          _ -> nil
        end

      age = if timestamp, do: Format.format_relative_time(timestamp), else: "-"

      %{
        tx_hash: string_or(transfer["transaction_hash"], "-"),
        block_number: parse_u64(transfer["block_number"]),
        age: age,
        maker_hash: string_or(get_in(transfer, ["to", "hash"]), ""),
        token_type: normalize_token_type(token_type),
        item_title: item_title,
        item_subtitle: collection_name,
        item_subtitle_is_address: collection_is_address,
        token_address: token_address(transfer),
        token_icon_url: string_or_nil(get_in(transfer, ["token", "icon_url"])),
        token_id: token_id,
        timestamp: timestamp
      }
    else
      nil
    end
  end

  defp extract_token_type(%{} = transfer) do
    case transfer["token_type"] do
      v when is_binary(v) -> String.trim(v) |> empty_to_nil()
      _ -> nil
    end ||
      case get_in(transfer, ["token", "type"]) do
        v when is_binary(v) -> String.trim(v) |> empty_to_nil()
        _ -> nil
      end
  end

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(v) when is_binary(v), do: v

  defp nft_transfer?(%{} = transfer, token_type) do
    is_nft_token_type?(token_type) or
      is_nft_token_type?(string_or_nil(get_in(transfer, ["token", "type"])))
  end

  defp is_nft_token_type?(nil), do: false

  defp is_nft_token_type?(v) when is_binary(v) do
    case String.trim(v) do
      "ERC-721" -> true
      "ERC-1155" -> true
      _ -> false
    end
  end

  defp mint_transfer?(%{} = transfer) do
    from_hash =
      case get_in(transfer, ["from", "hash"]) do
        v when is_binary(v) -> v
        _ -> ""
      end

    if String.downcase(from_hash) == @zero_address do
      true
    else
      case transfer["type"] do
        v when is_binary(v) ->
          case String.trim(v) do
            "token_minting" -> true
            "token_mint" -> true
            _ -> false
          end

        _ ->
          false
      end
    end
  end

  defp normalize_token_type(nil), do: "NFT"

  defp normalize_token_type(token_type) when is_binary(token_type) do
    token_type = String.trim(token_type)
    if token_type == "", do: "NFT", else: token_type
  end

  defp normalize_token_type(_), do: "NFT"

  defp resolve_collection_name(%{} = transfer) do
    token = transfer["token"]

    name =
      case get_in(transfer, ["token", "name"]) do
        v when is_binary(v) -> String.trim(v) |> empty_to_nil()
        _ -> nil
      end

    symbol =
      case get_in(transfer, ["token", "symbol"]) do
        v when is_binary(v) -> String.trim(v) |> empty_to_nil()
        _ -> nil
      end

    address =
      transfer
      |> token_address()
      |> case do
        v when is_binary(v) -> String.trim(v) |> empty_to_nil()
        _ -> nil
      end

    cond do
      is_binary(name) -> {name, false}
      is_binary(symbol) -> {symbol, false}
      is_binary(address) -> {address, true}
      is_map(token) -> {"Unknown NFT", false}
      true -> {"Unknown NFT", false}
    end
  end

  defp token_address(%{} = transfer) do
    string_or_nil(get_in(transfer, ["token", "address"])) ||
      string_or_nil(get_in(transfer, ["token", "address_hash"]))
  end

  defp build_item_title(collection_name, collection_is_address, nil)
       when is_binary(collection_name) and is_boolean(collection_is_address) do
    collection_name
  end

  defp build_item_title(collection_name, collection_is_address, token_id)
       when is_binary(collection_name) and is_boolean(collection_is_address) and
              is_binary(token_id) do
    token_id = String.trim(token_id)

    if token_id == "" do
      collection_name
    else
      if collection_is_address do
        "#" <> token_id
      else
        "#{collection_name} ##{token_id}"
      end
    end
  end

  defp export_collect_mints(page_size, cursor_query, filter)
       when is_integer(page_size) and (is_nil(cursor_query) or is_binary(cursor_query)) do
    page_size
    |> do_export_collect(cursor_query, filter, [], 0, 0)
    |> Enum.reverse()
  end

  defp do_export_collect(_page_size, _cursor_query, _filter, acc_rev, count, pages_fetched)
       when count >= @export_limit or pages_fetched >= @max_pages do
    acc_rev
  end

  defp do_export_collect(page_size, cursor_query, filter, acc_rev, count, pages_fetched) do
    path = token_transfers_path(page_size, cursor_query, @nft_types)

    case safe_get_json_cached(path, :public) do
      {:ok, %{} = json} ->
        items =
          case json["items"] do
            list when is_list(list) -> list
            _ -> []
          end

        {acc_rev, count} =
          Enum.reduce_while(items, {acc_rev, count}, fn
            _item, {acc, cnt} when cnt >= @export_limit ->
              {:halt, {acc, cnt}}

            %{} = item, {acc, cnt} ->
              case build_mint_display(item) do
                nil ->
                  {:cont, {acc, cnt}}

                %{} = mint ->
                  if matches_export_filter?(mint, filter) do
                    {:cont, {[mint | acc], cnt + 1}}
                  else
                    {:cont, {acc, cnt}}
                  end
              end

            _other, {acc, cnt} ->
              {:cont, {acc, cnt}}
          end)

        if count >= @export_limit do
          acc_rev
        else
          next_cursor_query =
            case Map.get(json, "next_page_params") do
              nil -> nil
              other -> Cursor.next_page_params_query(other)
            end

          pages_fetched = pages_fetched + 1

          if is_nil(next_cursor_query) do
            acc_rev
          else
            do_export_collect(page_size, next_cursor_query, filter, acc_rev, count, pages_fetched)
          end
        end

      {:ok, _other} ->
        acc_rev

      {:error, reason} ->
        Logger.warning("nfts: export upstream request failed",
          endpoint: "/api/v2/token-transfers",
          reason: inspect(reason)
        )

        acc_rev
    end
  end

  defp resolve_export_filter(params) when is_map(params) do
    mode = Map.get(params, "mode") || "date"

    case mode do
      "block" ->
        start =
          Map.get(params, "start_block")
          |> parse_block_number()
          |> case do
            nil -> 0
            v -> v
          end

        end_block =
          Map.get(params, "end_block")
          |> parse_block_number()
          |> case do
            nil -> :infinity
            v -> v
          end

        {start, end_block} =
          case end_block do
            :infinity ->
              {start, end_block}

            v when is_integer(v) and v >= 0 ->
              if start > v, do: {v, start}, else: {start, v}

            _ ->
              {start, :infinity}
          end

        {:block, start, end_block}

      _ ->
        today = Date.utc_today()
        default_start = Date.add(today, -30)

        start_date =
          Map.get(params, "start_date")
          |> parse_date()
          |> case do
            nil -> default_start
            d -> d
          end

        end_date =
          Map.get(params, "end_date")
          |> parse_date()
          |> case do
            nil -> today
            d -> d
          end

        {start_date, end_date} =
          if Date.compare(start_date, end_date) == :gt do
            {end_date, start_date}
          else
            {start_date, end_date}
          end

        {:date, start_date, end_date}
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(String.trim(value)) do
      {:ok, d} -> d
      _ -> nil
    end
  end

  defp parse_date(_), do: nil

  defp parse_block_number(nil), do: nil

  defp parse_block_number(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_block_number(value) when is_integer(value) and value >= 0, do: value
  defp parse_block_number(_), do: nil

  defp matches_export_filter?(%{} = mint, {:date, %Date{} = start_date, %Date{} = end_date}) do
    case mint.timestamp do
      v when is_binary(v) ->
        case DateTime.from_iso8601(String.trim(v)) do
          {:ok, dt, _offset} ->
            date = DateTime.to_date(dt)
            Date.compare(date, start_date) != :lt and Date.compare(date, end_date) != :gt

          _ ->
            false
        end

      _ ->
        false
    end
  end

  defp matches_export_filter?(%{} = mint, {:block, start_block, end_block})
       when is_integer(start_block) and (end_block == :infinity or is_integer(end_block)) do
    case mint.block_number do
      v when is_integer(v) and v >= 0 ->
        cond do
          end_block == :infinity -> v >= start_block
          true -> v >= start_block and v <= end_block
        end

      _ ->
        false
    end
  end

  defp matches_export_filter?(_mint, _filter), do: false

  defp build_mints_csv(mints) when is_list(mints) do
    header = "TxHash,Block,Timestamp,Age,Maker,Type,Item,Collection,TokenAddress,TokenId\n"

    csv =
      Enum.reduce(mints, header, fn mint, acc ->
        block =
          case mint.block_number do
            v when is_integer(v) -> Integer.to_string(v)
            _ -> ""
          end

        timestamp =
          case mint.timestamp do
            v when is_binary(v) -> v
            _ -> ""
          end

        token_address =
          case mint.token_address do
            v when is_binary(v) -> v
            _ -> ""
          end

        token_id =
          case mint.token_id do
            v when is_binary(v) -> v
            _ -> ""
          end

        row =
          [
            csv_cell(to_string(mint.tx_hash)),
            csv_cell(block),
            csv_cell(timestamp),
            csv_cell(to_string(mint.age)),
            csv_cell(to_string(mint.maker_hash)),
            csv_cell(to_string(mint.token_type)),
            csv_cell(to_string(mint.item_title)),
            csv_cell(to_string(mint.item_subtitle)),
            csv_cell(token_address),
            csv_cell(token_id)
          ]
          |> Enum.join(",")

        acc <> row <> "\n"
      end)

    csv
  end

  defp csv_cell(value) when is_binary(value) do
    prefix =
      case String.first(value) do
        "=" -> "'"
        "+" -> "'"
        "-" -> "'"
        "@" -> "'"
        _ -> ""
      end

    escaped = String.replace(value, "\"", "\"\"")
    "\"" <> prefix <> escaped <> "\""
  end

  defp string_or(v, _default) when is_binary(v), do: v
  defp string_or(_v, default), do: default

  defp string_or_nil(v) when is_binary(v) do
    v = String.trim(v)
    if v == "", do: nil, else: v
  end

  defp string_or_nil(_), do: nil

  defp parse_u64(v) when is_integer(v) and v >= 0, do: v

  defp parse_u64(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  defp parse_u64(_), do: nil
end
