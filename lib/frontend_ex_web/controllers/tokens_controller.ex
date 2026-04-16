defmodule FrontendExWeb.TokensController do
  use FrontendExWeb, :controller

  alias FrontendEx.Blockscout.Client
  alias FrontendExWeb.TokensHTML

  @tokens_limit 50

  def index(conn, _params) do
    skin = FrontendExWeb.Skin.current()

    safe_empty = safe_empty()

    explorer_url = explorer_url()

    stats_path = "/api/v2/stats"
    tokens_path = "/api/v2/tokens?limit=#{@tokens_limit}"

    stats_task = Task.async(fn -> Client.get_json_cached(stats_path, :public) end)
    tokens_task = Task.async(fn -> Client.get_json_cached(tokens_path, :public) end)

    [stats_json, tokens_json] =
      await_many_ok([{stats_path, stats_task}, {tokens_path, tokens_task}], "tokens")

    {coin_price, gas_price} = derive_coin_gas(stats_json)
    tokens = parse_tokens(tokens_json)

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
      tokens: tokens,
      coin_price: coin_price,
      gas_price: gas_price
    }

    case skin do
      :classic ->
        styles = TokensHTML.classic_styles(base_assigns)

        render(conn, :classic_content, %{
          base_assigns
          | page_title: "Tokens | Sepolia",
            nav_tokens: "active",
            styles: styles
        })

      :s53627 ->
        styles = TokensHTML.s53627_styles(base_assigns)

        render(conn, :s53627_content, %{
          base_assigns
          | page_title: "Tokens | Sepolia",
            styles: styles
        })
    end
  end

  defp parse_tokens(nil), do: []

  defp parse_tokens(%{} = json) do
    items =
      case json["items"] do
        list when is_list(list) -> list
        _ -> []
      end

    items
    |> Enum.take(@tokens_limit)
    |> Enum.flat_map(fn
      %{} = token -> [display_token(token)]
      _ -> []
    end)
  end

  defp parse_tokens(_), do: []

  defp display_token(%{} = token) do
    %{
      address_hash: string_or_nil(token["address_hash"]),
      name: string_or_nil(token["name"]),
      symbol: string_or_nil(token["symbol"]),
      token_type: string_or_nil(token["type"]),
      icon_url: string_or_nil(token["icon_url"]),
      holders_count: string_or_nil(token["holders_count"])
    }
  end

  defp string_or_nil(nil), do: nil
  defp string_or_nil(v) when is_binary(v), do: v
  defp string_or_nil(v) when is_integer(v), do: Integer.to_string(v)
  defp string_or_nil(_), do: nil
end
