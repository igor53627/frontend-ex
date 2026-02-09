defmodule FrontendExWeb.TokenHTML do
  @moduledoc false

  use FrontendExWeb, :html

  alias FrontendEx.Format

  embed_templates "token_html/*"
end
