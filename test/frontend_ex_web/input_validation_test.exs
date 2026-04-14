defmodule FrontendExWeb.InputValidationTest do
  use FrontendExWeb.ConnCase, async: true

  describe "AddressController input validation" do
    test "returns 404 for invalid address format", %{conn: conn} do
      conn = get(conn, "/address/not-a-valid-address")
      assert response(conn, 404) =~ "Address not found"
    end

    test "returns 404 for short hex", %{conn: conn} do
      conn = get(conn, "/address/0xdead")
      assert response(conn, 404) =~ "Address not found"
    end

    test "returns 404 for address with extra chars", %{conn: conn} do
      conn = get(conn, "/address/0x" <> String.duplicate("a", 40) <> "xx")
      assert response(conn, 404) =~ "Address not found"
    end
  end

  describe "TokenController input validation" do
    test "returns 404 for invalid token address", %{conn: conn} do
      conn = get(conn, "/token/not-valid")
      assert response(conn, 404) =~ "Token not found"
    end

    test "returns 404 for invalid token holders address", %{conn: conn} do
      conn = get(conn, "/token/not-valid/holders")
      assert response(conn, 404) =~ "Token not found"
    end
  end

  describe "BlockController input validation" do
    test "returns 404 for non-numeric non-hash block id", %{conn: conn} do
      conn = get(conn, "/block/abc-not-valid")
      assert response(conn, 404) =~ "Block not found"
    end

    test "returns 404 for invalid block id in txs", %{conn: conn} do
      conn = get(conn, "/block/abc-not-valid/txs")
      assert response(conn, 404) =~ "Block not found"
    end
  end
end
