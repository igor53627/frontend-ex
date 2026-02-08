defmodule FrontendExWeb.ExportDataParityTest do
  use FrontendExWeb.ConnCase, async: true

  @golden_path Path.expand("../golden/exportData.classic.rust.html", __DIR__)

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
    expected = File.read!(@golden_path)

    assert body == expected
  end
end
