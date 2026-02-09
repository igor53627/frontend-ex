defmodule FrontendExWeb.AddressHTML do
  @moduledoc false

  use FrontendExWeb, :html

  embed_templates "address_html/*"

  # Rust templates bold the decimal point in fee display: `0<b>.</b>000021`.
  def dot_bold(value) when is_binary(value) do
    case String.split(value, ".", parts: 2) do
      [int_part, frac_part] -> Phoenix.HTML.raw(int_part <> "<b>.</b>" <> frac_part)
      _ -> value
    end
  end

  def dot_bold(value), do: value
end
