defmodule FrontendExWeb.ExportDataController do
  use FrontendExWeb, :controller

  alias FrontendExWeb.ExportDataHTML

  def index(conn, params) do
    skin = FrontendExWeb.Skin.current()

    export_type =
      case params["type"] do
        "nft-mints" -> "nft-mints"
        _ -> "nft-mints"
      end

    export_label = "Latest NFT Mints (ERC-721 & ERC-1155)"

    mode = params["mode"] || "date"
    is_date_mode = mode != "block"
    is_block_mode = not is_date_mode

    today = Date.utc_today()
    default_start = Date.add(today, -30)

    start_date = parse_date(params["start_date"]) || default_start
    end_date = parse_date(params["end_date"]) || today

    start_block = params["start_block"] || ""
    end_block = params["end_block"] || ""

    explorer_url = Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")

    base_assigns = %{
      page_title: "",
      explorer_url: explorer_url,
      export_type: export_type,
      export_label: export_label,
      is_date_mode: is_date_mode,
      is_block_mode: is_block_mode,
      start_date: Date.to_string(start_date),
      end_date: Date.to_string(end_date),
      start_block: start_block,
      end_block: end_block,
      head_meta: "",
      scripts: "",
      styles: "",
      topbar: ""
    }

    case skin do
      :classic ->
        styles = ExportDataHTML.classic_styles(base_assigns) |> Phoenix.HTML.safe_to_string()

        render(conn, :classic_content, %{
          base_assigns
          | page_title: "CSV Export | Sepolia",
            styles: styles
        })

      :s53627 ->
        render(conn, :s53627_content, %{
          base_assigns
          | page_title: "CSV Export | Explorer"
        })
    end
  end

  defp parse_date(nil), do: nil

  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(String.trim(value)) do
      {:ok, d} -> d
      _ -> nil
    end
  end
end
