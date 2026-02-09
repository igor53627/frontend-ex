defmodule FrontendExWeb.TokensHTML do
  @moduledoc false

  use FrontendExWeb, :html

  embed_templates "tokens_html/*"

  def first_letter_or_q(nil), do: "?"

  def first_letter_or_q(value) when is_binary(value) do
    case String.first(value) do
      nil -> "?"
      other -> other
    end
  end

  def first_letter_or_q(_), do: "?"
end

