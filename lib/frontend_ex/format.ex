defmodule FrontendEx.Format do
  @moduledoc false

  alias FrontendEx.Clock

  @wei_per_eth 1_000_000_000_000_000_000
  @wei_lt_0_000001_eth 1_000_000_000_000
  @wei_lt_0_001_eth 1_000_000_000_000_000

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
end
