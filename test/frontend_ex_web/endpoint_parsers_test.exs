defmodule FrontendExWeb.EndpointParsersTest do
  @moduledoc """
  Locks in the Plug.Parsers hardening:
    * bodies above the configured length cap must fail with 413
    * unknown content-types (no `pass: ["*/*"]`) must fail with 415
  """
  use FrontendExWeb.ConnCase, async: false

  @health_path "/health"

  describe "Plug.Parsers oversize body" do
    test "POST with body exceeding 1 MB returns 413", %{conn: conn} do
      oversize = :binary.copy("a=b&", 300_000)

      assert_raise Plug.Parsers.RequestTooLargeError, fn ->
        conn
        |> put_req_header("content-type", "application/x-www-form-urlencoded")
        |> post(@health_path, oversize)
      end
    end
  end

  describe "Plug.Parsers content-type allowlist" do
    test "POST with unsupported content-type returns 415", %{conn: conn} do
      assert_raise Plug.Parsers.UnsupportedMediaTypeError, fn ->
        conn
        |> put_req_header("content-type", "application/octet-stream")
        |> post(@health_path, "some bytes")
      end
    end
  end
end
