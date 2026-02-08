defmodule FrontendEx.Blockscout.RequestAdapter do
  @moduledoc false

  @type result :: {:ok, Req.Response.t()} | {:error, term()}

  @callback request_raw(binary()) :: result()
end
