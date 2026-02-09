defmodule FrontendExWeb.Plugs.TrimTrailingNewline do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    register_before_send(conn, fn conn ->
      body = conn.resp_body

      cond do
        is_binary(body) ->
          %{conn | resp_body: trim_binary_trailing_newlines(body)}

        is_list(body) ->
          %{conn | resp_body: trim_iodata_trailing_newlines(body)}

        true ->
          conn
      end
    end)
  end

  defp trim_binary_trailing_newlines(bin) when is_binary(bin) do
    size = byte_size(bin)

    if size > 0 and :binary.at(bin, size - 1) == ?\n do
      trim_binary_trailing_newlines(bin, size - 1)
    else
      bin
    end
  end

  defp trim_binary_trailing_newlines(_bin, 0), do: ""

  defp trim_binary_trailing_newlines(bin, n) when is_binary(bin) and is_integer(n) and n > 0 do
    if :binary.at(bin, n - 1) == ?\n do
      trim_binary_trailing_newlines(bin, n - 1)
    else
      binary_part(bin, 0, n)
    end
  end

  defp trim_iodata_trailing_newlines(iodata) do
    {trimmed, _still_trimming} = trim_iodata(iodata)
    trimmed
  end

  # Returns {trimmed, still_trimming?}. still_trimming? is true only if the
  # entire input was removed (empty or only trailing newlines).
  defp trim_iodata(iodata) when is_list(iodata), do: trim_list(iodata)

  defp trim_iodata(iodata) when is_binary(iodata) do
    trimmed = trim_binary_trailing_newlines(iodata)

    if trimmed == "" do
      {[], true}
    else
      {trimmed, false}
    end
  end

  defp trim_iodata(iodata) when is_integer(iodata) and iodata >= 0 and iodata <= 255 do
    if iodata == ?\n do
      {[], true}
    else
      {iodata, false}
    end
  end

  defp trim_iodata(other), do: {other, false}

  defp trim_list([]), do: {[], true}

  defp trim_list([h | t] = original) do
    {trimmed_t, trimming?} = trim_list(t)

    cond do
      trimming? ->
        {trimmed_h, trimming_h?} = trim_iodata(h)

        if trimmed_h == [] do
          {trimmed_t, trimming_h?}
        else
          # Keep trimmed_h; trailing newlines are fully removed now.
          {[trimmed_h | trimmed_t], false}
        end

      trimmed_t == t ->
        # Nothing changed in the tail and we're not trimming anymore; reuse the
        # original list to avoid allocating a new one.
        {original, false}

      true ->
        {[h | trimmed_t], false}
    end
  end
end
