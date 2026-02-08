defmodule FrontendEx.Blockscout.RequestAdapter.Fixture do
  @moduledoc false

  @behaviour FrontendEx.Blockscout.RequestAdapter

  @impl true
  def request_raw(url) when is_binary(url) do
    fixture_dir = fixture_dir!()
    uri = URI.parse(url)
    path = uri.path || raise "fixture adapter requires a URL with a path: #{inspect(url)}"

    {dir, base} = fixture_base_path(fixture_dir, path, uri.query)

    resp_path = Path.join(dir, base <> ".resp.json")
    body_path = Path.join(dir, base <> ".json")

    cond do
      File.exists?(resp_path) ->
        render_resp(File.read!(resp_path), url)

      File.exists?(body_path) ->
        body = File.read!(body_path)

        {:ok,
         %Req.Response{
           status: 200,
           headers: [{"content-type", "application/json"}],
           body: body
         }}

      true ->
        case Application.get_env(:frontend_ex, :blockscout_fixture_on_missing, :raise) do
          :not_found ->
            {:ok, %Req.Response{status: 404, headers: [], body: ""}}

          other ->
            raise """
            missing Blockscout HTTP fixture for #{url}
            tried:
              - #{resp_path}
              - #{body_path}
            on_missing=#{inspect(other)}
            """
        end
    end
  end

  defp fixture_dir! do
    Application.get_env(:frontend_ex, :blockscout_fixture_dir) ||
      raise "missing :frontend_ex, :blockscout_fixture_dir (required for Fixture adapter)"
  end

  defp fixture_base_path(fixture_dir, path, query) do
    segments = String.split(to_string(path), "/", trim: true)

    {dirs, leaf} =
      case segments do
        [] -> {[], "root"}
        _ -> {Enum.drop(segments, -1), List.last(segments)}
      end

    dir = Path.join([fixture_dir | dirs])

    base =
      case query do
        nil -> leaf
        "" -> leaf
        q -> leaf <> query_suffix(q)
      end

    {dir, base}
  end

  defp query_suffix(query) when is_binary(query) do
    canonical = canonical_query(query)

    safe_query =
      canonical
      |> String.replace(~r/[^A-Za-z0-9._-]/, "_")

    hash8 =
      :crypto.hash(:sha256, canonical)
      |> Base.encode16(case: :lower)
      |> binary_part(0, 8)

    "__" <> safe_query <> "--" <> hash8
  end

  defp canonical_query(query) when is_binary(query) do
    query
    |> URI.decode_query()
    |> Enum.sort()
    |> URI.encode_query()
  end

  defp render_resp(bytes, url) when is_binary(bytes) and is_binary(url) do
    case Jason.decode(bytes) do
      {:ok, %{"status" => status} = decoded} when is_integer(status) ->
        headers =
          case Map.get(decoded, "headers") do
            nil ->
              []

            list when is_list(list) ->
              Enum.map(list, fn
                [k, v] when is_binary(k) and is_binary(v) -> {k, v}
                other -> raise "invalid headers entry in #{url} fixture: #{inspect(other)}"
              end)

            other ->
              raise "invalid headers in #{url} fixture: #{inspect(other)}"
          end

        body =
          case Map.get(decoded, "body", "") do
            b when is_binary(b) -> b
            other -> Jason.encode!(other)
          end

        {:ok, %Req.Response{status: status, headers: headers, body: body}}

      {:ok, other} ->
        raise "invalid .resp.json fixture for #{url}: #{inspect(other)}"

      {:error, err} ->
        raise "invalid JSON in .resp.json fixture for #{url}: #{inspect(err)}"
    end
  end
end
