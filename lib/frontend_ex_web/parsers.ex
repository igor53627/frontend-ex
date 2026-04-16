defmodule FrontendExWeb.Parsers do
  @moduledoc """
  Input parsers and validators shared by controllers.

  Exposed via the `:controller` macro in `frontend_ex_web.ex`, so every
  controller can call these directly (`parse_u64/1`, `eth_address?/1`, …).

  Validators return booleans; parsers return a value or `nil` / an explicit
  fallback. None of these functions raise on malformed input.
  """

  @address_re ~r/\A0x[0-9a-fA-F]{40}\z/i
  @hash32_re ~r/\A0x[0-9a-fA-F]{64}\z/i
  @decimal_re ~r/\A\d+\z/

  @doc "Regex matching an EVM address (`0x` + 40 hex chars, case-insensitive prefix)."
  @spec address_regex() :: Regex.t()
  def address_regex, do: @address_re

  @doc "Regex matching a 32-byte hex hash (tx hash or block hash), case-insensitive prefix."
  @spec hash32_regex() :: Regex.t()
  def hash32_regex, do: @hash32_re

  @doc """
  Returns `true` iff `v` is an EVM-style address (`0x` + 40 hex chars). The
  prefix is case-insensitive (`0x` or `0X`).

  Does not trim; callers should trim first if needed.
  """
  @spec eth_address?(term()) :: boolean()
  def eth_address?(v) when is_binary(v), do: Regex.match?(@address_re, v)
  def eth_address?(_), do: false

  @doc """
  Returns `true` iff `v` is a 32-byte hex hash (`0x` + 64 hex chars). The
  prefix is case-insensitive. Covers transaction and block hashes alike.
  """
  @spec tx_hash?(term()) :: boolean()
  def tx_hash?(v) when is_binary(v), do: Regex.match?(@hash32_re, v)
  def tx_hash?(_), do: false

  @doc """
  Returns `true` iff `v` is a valid block identifier: either a non-negative
  decimal string (block number) or a 32-byte hex hash.
  """
  @spec block_id?(term()) :: boolean()
  def block_id?(v) when is_binary(v),
    do: Regex.match?(@decimal_re, v) or Regex.match?(@hash32_re, v)

  def block_id?(_), do: false

  @doc """
  Parses a non-negative integer (`u64`-shaped) from an integer or binary.
  Whitespace in binaries is trimmed. Returns `nil` on any failure.
  """
  @spec parse_u64(term()) :: non_neg_integer() | nil
  def parse_u64(v) when is_integer(v) and v >= 0, do: v

  def parse_u64(v) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} when n >= 0 -> n
      _ -> nil
    end
  end

  def parse_u64(_), do: nil

  @doc """
  Parses an integer from a binary or returns it passthrough if already an
  integer. Returns `fallback` for `nil`, unparseable binaries, or any other
  shape. Whitespace in binaries is trimmed.
  """
  @spec parse_int_or(term(), term()) :: integer() | term()
  def parse_int_or(nil, fallback), do: fallback
  def parse_int_or(v, _fallback) when is_integer(v), do: v

  def parse_int_or(v, fallback) when is_binary(v) do
    case Integer.parse(String.trim(v)) do
      {n, ""} -> n
      _ -> fallback
    end
  end

  def parse_int_or(_v, fallback), do: fallback

  @doc """
  Returns a trimmed binary, or `nil` for any non-binary input.
  """
  @spec normalize_opt_string(term()) :: binary() | nil
  def normalize_opt_string(v) when is_binary(v), do: String.trim(v)
  def normalize_opt_string(_), do: nil
end
