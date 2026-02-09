defmodule FrontendEx.Format do
  @moduledoc false

  alias FrontendEx.Clock

  import Bitwise

  @wei_per_eth 1_000_000_000_000_000_000
  @wei_lt_0_000001_eth 1_000_000_000_000
  @wei_lt_0_001_eth 1_000_000_000_000_000
  @wei_per_gwei 1_000_000_000

  @spec format_wei_to_eth(binary()) :: binary()
  def format_wei_to_eth(wei_str) when is_binary(wei_str) do
    wei_str = String.trim(wei_str)

    case Integer.parse(wei_str) do
      {wei, ""} when wei > 0 ->
        cond do
          wei < @wei_lt_0_000001_eth -> format_eth_rounded(wei, 8)
          wei < @wei_lt_0_001_eth -> format_eth_rounded(wei, 6)
          true -> format_eth_rounded(wei, 4)
        end

      {0, ""} ->
        "0"

      _ ->
        "0"
    end
  end

  @spec format_wei_to_eth_exact(binary()) :: binary()
  def format_wei_to_eth_exact(wei_str) when is_binary(wei_str) do
    wei_str = String.trim(wei_str)

    case Integer.parse(wei_str) do
      {wei, ""} when is_integer(wei) and wei >= 0 ->
        eth_int = div(wei, @wei_per_eth)
        eth_frac = rem(wei, @wei_per_eth)

        if eth_frac == 0 do
          Integer.to_string(eth_int)
        else
          frac =
            eth_frac
            |> Integer.to_string()
            |> String.pad_leading(18, "0")
            |> String.trim_trailing("0")

          "#{eth_int}.#{frac}"
        end

      _ ->
        "0"
    end
  end

  @spec format_wei_to_gwei(binary()) :: binary()
  def format_wei_to_gwei(wei_str) when is_binary(wei_str) do
    wei_str = String.trim(wei_str)

    case Integer.parse(wei_str) do
      {wei, ""} when is_integer(wei) and wei >= 0 ->
        if wei == 0 do
          "0"
        else
          gwei_int = div(wei, @wei_per_gwei)
          gwei_frac = rem(wei, @wei_per_gwei)

          if gwei_frac == 0 do
            Integer.to_string(gwei_int)
          else
            frac =
              gwei_frac
              |> Integer.to_string()
              |> String.pad_leading(9, "0")
              |> String.trim_trailing("0")

            if frac == "" do
              Integer.to_string(gwei_int)
            else
              "#{gwei_int}.#{frac}"
            end
          end
        end

      _ ->
        "0"
    end
  end

  defp format_eth_rounded(wei, decimals) when is_integer(wei) and wei >= 0 and decimals >= 0 do
    pow10 = Integer.pow(10, decimals)

    # Round half-up to the requested number of decimals.
    numerator = wei * pow10
    scaled = div(numerator + div(@wei_per_eth, 2), @wei_per_eth)

    int_part = div(scaled, pow10)
    frac_part = rem(scaled, pow10)

    if decimals == 0 do
      Integer.to_string(int_part)
    else
      frac = frac_part |> Integer.to_string() |> String.pad_leading(decimals, "0")
      "#{int_part}.#{frac}"
    end
  end

  @spec format_method_name(binary()) :: binary()
  def format_method_name(method) when is_binary(method) do
    trimmed = String.trim(method)

    cond do
      trimmed == "" ->
        "-"

      String.starts_with?(trimmed, "0x") ->
        trimmed

      true ->
        spaced =
          trimmed
          |> String.graphemes()
          |> Enum.reduce({[], false, false}, fn ch, {acc, prev_lower, prev_digit} ->
            cond do
              ch == "_" or ch == "-" ->
                acc =
                  case acc do
                    [" " | _] -> acc
                    _ -> [" " | acc]
                  end

                {acc, false, false}

              true ->
                is_upper = ch >= "A" and ch <= "Z"
                is_lower = ch >= "a" and ch <= "z"
                is_digit = ch >= "0" and ch <= "9"

                acc =
                  cond do
                    is_upper and (prev_lower or prev_digit) -> [ch, " " | acc]
                    is_digit and prev_lower -> [ch, " " | acc]
                    true -> [ch | acc]
                  end

                {acc, is_lower, is_digit}
            end
          end)
          |> then(fn {acc, _pl, _pd} -> acc |> Enum.reverse() |> Enum.join("") end)

        spaced
        |> String.split(~r/\s+/, trim: true)
        |> Enum.map(fn word ->
          is_all_caps =
            word
            |> String.to_charlist()
            |> Enum.all?(fn c -> not (c >= ?a and c <= ?z) end)

          if is_all_caps do
            word
          else
            [first | rest] = String.graphemes(word)
            String.upcase(first) <> String.downcase(Enum.join(rest, ""))
          end
        end)
        |> Enum.join(" ")
    end
  end

  @spec checksum_eth_address(binary()) :: binary()
  def checksum_eth_address(addr) when is_binary(addr) do
    trimmed = String.trim(addr)

    hex =
      cond do
        String.starts_with?(trimmed, "0x") -> String.slice(trimmed, 2..-1//1)
        String.starts_with?(trimmed, "0X") -> String.slice(trimmed, 2..-1//1)
        true -> nil
      end

    cond do
      is_nil(hex) ->
        trimmed

      String.length(hex) != 40 ->
        trimmed

      not String.match?(hex, ~r/\A[0-9A-Fa-f]{40}\z/) ->
        trimmed

      true ->
        lower = String.downcase(hex)
        hash = KeccakEx.hash_256(lower)

        checksummed =
          lower
          |> String.graphemes()
          |> Enum.with_index()
          |> Enum.map(fn {ch, i} ->
            if ch >= "0" and ch <= "9" do
              ch
            else
              byte = :binary.at(hash, div(i, 2))
              nibble = if rem(i, 2) == 0, do: (byte >>> 4), else: (byte &&& 0x0F)
              if nibble >= 8, do: String.upcase(ch), else: ch
            end
          end)
          |> Enum.join("")

        "0x" <> checksummed
    end
  end

  @spec format_number_with_commas(binary()) :: binary()
  def format_number_with_commas(s) when is_binary(s) do
    s = String.trim(s)

    case Integer.parse(s) do
      {n, ""} when n >= 0 ->
        n
        |> Integer.to_string()
        |> String.graphemes()
        |> Enum.reverse()
        |> Enum.chunk_every(3)
        |> Enum.map(&Enum.reverse/1)
        |> Enum.reverse()
        |> Enum.map(&Enum.join/1)
        |> Enum.join(",")

      _ ->
        s
    end
  end

  @spec format_price_with_commas(binary()) :: binary()
  def format_price_with_commas(s) when is_binary(s) do
    case String.split(s, ".", parts: 2) do
      [int_part, frac_part] ->
        format_number_with_commas(int_part) <> "." <> frac_part

      [int_part] ->
        format_number_with_commas(int_part)
    end
  end

  @spec truncate_hash(binary()) :: binary()
  def truncate_hash(s) when is_binary(s) do
    if byte_size(s) > 12 do
      prefix = binary_part(s, 0, 6)
      suffix = binary_part(s, byte_size(s) - 4, 4)
      prefix <> "..." <> suffix
    else
      s
    end
  end

  @spec truncate_addr(binary()) :: binary()
  def truncate_addr(s) when is_binary(s) do
    if byte_size(s) > 10 do
      prefix = binary_part(s, 0, min(4, byte_size(s)))
      suffix = binary_part(s, max(byte_size(s) - 4, 0), min(4, byte_size(s)))
      prefix <> "..." <> suffix
    else
      s
    end
  end

  @spec truncate_addr_classic(binary()) :: binary()
  def truncate_addr_classic(s) when is_binary(s) do
    prefix_len = 10
    suffix_len = 9

    if byte_size(s) <= prefix_len + suffix_len + 3 do
      s
    else
      prefix = binary_part(s, 0, min(prefix_len, byte_size(s)))
      suffix_start = max(byte_size(s) - suffix_len, 0)
      suffix = binary_part(s, suffix_start, byte_size(s) - suffix_start)
      prefix <> "..." <> suffix
    end
  end

  @spec format_relative_time(binary()) :: binary()
  def format_relative_time(timestamp) when is_binary(timestamp) do
    timestamp = String.trim(timestamp)

    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} ->
        now = Clock.utc_now()
        secs = max(DateTime.diff(now, dt, :second), 0)

        cond do
          secs < 60 ->
            unit = if secs == 1, do: "sec", else: "secs"
            "#{secs} #{unit} ago"

          secs < 3600 ->
            mins = div(secs, 60)
            unit = if mins == 1, do: "min", else: "mins"
            "#{mins} #{unit} ago"

          secs < 86_400 ->
            hours = div(secs, 3600)
            unit = if hours == 1, do: "hr", else: "hrs"
            "#{hours} #{unit} ago"

          true ->
            days = div(secs, 86_400)

            cond do
              days < 30 ->
                unit = if days == 1, do: "day", else: "days"
                "#{days} #{unit} ago"

              days < 365 ->
                months = div(days, 30)
                unit = if months == 1, do: "mth", else: "mths"
                "#{months} #{unit} ago"

              true ->
                years = div(days, 365)
                unit = if years == 1, do: "yr", else: "yrs"
                "#{years} #{unit} ago"
            end
        end

      _ ->
        timestamp
    end
  end

  @spec format_readable_date(binary()) :: binary()
  def format_readable_date(timestamp) when is_binary(timestamp) do
    timestamp = String.trim(timestamp)

    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} ->
        Calendar.strftime(dt, "%b %d, %Y %H:%M:%S UTC")

      _ ->
        timestamp
    end
  end

  @spec format_readable_date_classic_plus_utc(binary()) :: binary()
  def format_readable_date_classic_plus_utc(timestamp) when is_binary(timestamp) do
    timestamp = String.trim(timestamp)

    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} ->
        Calendar.strftime(dt, "%b-%d-%Y %I:%M:%S %p +UTC")

      _ ->
        timestamp
    end
  end

  @spec format_readable_date_classic(binary()) :: binary()
  def format_readable_date_classic(timestamp) when is_binary(timestamp) do
    timestamp = String.trim(timestamp)

    case DateTime.from_iso8601(timestamp) do
      {:ok, dt, _offset} ->
        Calendar.strftime(dt, "%b-%d-%Y %I:%M:%S %p UTC")

      _ ->
        timestamp
    end
  end
end
