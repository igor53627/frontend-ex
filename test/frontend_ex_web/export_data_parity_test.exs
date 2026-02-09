defmodule FrontendExWeb.ExportDataParityTest do
  # Parity tests mutate global Application env (skin, URLs), so they must be serial.
  use FrontendExWeb.ConnCase, async: false

  alias FrontendEx.TestSupport.Golden

  @golden_classic_path Path.expand("../golden/exportData.classic.rust.html", __DIR__)
  @golden_53627_path Path.expand("../golden/exportData.53627.rust.html", __DIR__)

  test "classic /exportData matches Rust HTML byte-for-byte" do
    prev_skin = Application.get_env(:frontend_ex, :ff_skin)
    Application.put_env(:frontend_ex, :ff_skin, "classic")

    on_exit(fn ->
      if is_nil(prev_skin) do
        Application.delete_env(:frontend_ex, :ff_skin)
      else
        Application.put_env(:frontend_ex, :ff_skin, prev_skin)
      end
    end)

    conn =
      get(build_conn(), "/exportData", %{
        "type" => "nft-mints",
        "mode" => "date",
        "start_date" => "2026-01-01",
        "end_date" => "2026-02-01",
        "start_block" => "123",
        "end_block" => "456"
      })

    body = html_response(conn, 200)

    Golden.assert_golden!(@golden_classic_path, body)
  end

  test "53627 /exportData matches Rust HTML byte-for-byte" do
    prev_skin = Application.get_env(:frontend_ex, :ff_skin)
    Application.put_env(:frontend_ex, :ff_skin, "53627")

    on_exit(fn ->
      if is_nil(prev_skin) do
        Application.delete_env(:frontend_ex, :ff_skin)
      else
        Application.put_env(:frontend_ex, :ff_skin, prev_skin)
      end
    end)

    conn =
      get(build_conn(), "/exportData", %{
        "type" => "nft-mints",
        "mode" => "date",
        "start_date" => "2026-01-01",
        "end_date" => "2026-02-01",
        "start_block" => "123",
        "end_block" => "456"
      })

    body = html_response(conn, 200)

    Golden.assert_golden!(@golden_53627_path, body)
  end
end
