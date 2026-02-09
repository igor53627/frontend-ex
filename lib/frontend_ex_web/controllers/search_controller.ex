defmodule FrontendExWeb.SearchController do
  use FrontendExWeb, :controller

  @hex40 ~r/\A0x[0-9a-fA-F]{40}\z/
  @hex64 ~r/\A0x[0-9a-fA-F]{64}\z/
  @digits ~r/\A[0-9]+\z/

  def index(conn, params) do
    q =
      params
      |> Map.get("q", "")
      |> to_string()
      |> String.trim()

    cond do
      q == "" ->
        redirect(conn, to: "/")

      String.match?(q, @hex40) ->
        redirect(conn, to: "/address/#{q}")

      String.match?(q, @hex64) ->
        redirect(conn, to: "/tx/#{q}")

      String.match?(q, @digits) ->
        redirect(conn, to: "/block/#{q}")

      true ->
        explorer_url =
          Application.get_env(:frontend_ex, :blockscout_url, "https://sepolia.53627.org")
          |> to_string()
          |> String.trim()
          |> String.trim_trailing("/")

        # Encode to avoid generating an invalid Location header for inputs like "foo bar".
        qs = URI.encode_query(%{"q" => q})
        redirect(conn, external: "#{explorer_url}/search?#{qs}")
    end
  end
end
