defmodule FrontendEx.Blockscout.FixtureAdapterTest do
  use ExUnit.Case, async: true

  alias FrontendEx.Blockscout.Client

  test "fixture adapter serves JSON from disk (no network)" do
    assert {:ok, %{"total_blocks" => "9829593"}} = Client.get_json_uncached("/api/v2/stats")
  end
end
