defmodule FrontendEx.VersionTest do
  # Some tests here mutate global `:backend_version_override` in the
  # application env, which is process-global. Keep this non-async so we
  # don't race other tests that read it.
  use ExUnit.Case, async: false

  alias FrontendEx.Version

  describe "parse_health_response/1 — happy path" do
    test "version + commit → struct with 12-char sha" do
      assert Version.parse_health_response(%{
               "version" => "0.4.4",
               "commit" => "22155e90abcd"
             }) == %{version: "0.4.4", sha: "22155e90abcd"}
    end

    test "commit longer than 12 chars is truncated" do
      assert Version.parse_health_response(%{
               "version" => "0.4.4",
               "commit" => "22155e90abcdef1234567890"
             }) == %{version: "0.4.4", sha: "22155e90abcd"}
    end

    test "commit shorter than 12 chars is kept as-is" do
      assert Version.parse_health_response(%{
               "version" => "0.4.4",
               "commit" => "22155e9"
             }) == %{version: "0.4.4", sha: "22155e9"}
    end
  end

  describe "parse_health_response/1 — sha fallback" do
    test "missing commit → sha is nil" do
      assert Version.parse_health_response(%{"version" => "0.4.4"}) ==
               %{version: "0.4.4", sha: nil}
    end

    test "empty-string commit → sha is nil" do
      assert Version.parse_health_response(%{
               "version" => "0.4.4",
               "commit" => ""
             }) == %{version: "0.4.4", sha: nil}
    end

    test "non-binary commit → sha is nil" do
      assert Version.parse_health_response(%{
               "version" => "0.4.4",
               "commit" => 12_345
             }) == %{version: "0.4.4", sha: nil}
    end
  end

  describe "parse_health_response/1 — invalid input" do
    test "missing version → nil" do
      assert Version.parse_health_response(%{"commit" => "abc"}) == nil
    end

    test "empty-string version → nil" do
      assert Version.parse_health_response(%{"version" => ""}) == nil
    end

    test "non-binary version → nil" do
      assert Version.parse_health_response(%{"version" => 123}) == nil
    end

    test "non-map input → nil" do
      assert Version.parse_health_response(nil) == nil
      assert Version.parse_health_response("healthy") == nil
      assert Version.parse_health_response([]) == nil
    end
  end

  describe "parse_health_response/1 — v-prefix stripping" do
    test "strips lowercase v before digit" do
      assert %{version: "0.4.4"} = Version.parse_health_response(%{"version" => "v0.4.4"})
    end

    test "strips uppercase V before digit" do
      assert %{version: "0.4.4"} = Version.parse_health_response(%{"version" => "V0.4.4"})
    end

    test "does NOT strip v when not followed by a digit" do
      assert %{version: "version-string"} =
               Version.parse_health_response(%{"version" => "version-string"})
    end

    test "leaves vv-prefixed string alone (second char not a digit)" do
      # Strip rule is `v` or `V` followed directly by a digit. `vv1.0.0` starts
      # with `vv` (not `v<digit>`), so it's considered malformed and kept
      # verbatim rather than recursively peeled.
      assert %{version: "vv1.0.0"} =
               Version.parse_health_response(%{"version" => "vv1.0.0"})
    end
  end

  describe "backend/0 — override handling" do
    setup do
      prior =
        case Application.fetch_env(:frontend_ex, :backend_version_override) do
          {:ok, v} -> {:present, v}
          :error -> :absent
        end

      on_exit(fn ->
        case prior do
          {:present, v} -> Application.put_env(:frontend_ex, :backend_version_override, v)
          :absent -> Application.delete_env(:frontend_ex, :backend_version_override)
        end
      end)

      :ok
    end

    test "nil override returns nil" do
      Application.put_env(:frontend_ex, :backend_version_override, nil)
      assert Version.backend() == nil
    end

    test "bare binary override becomes {version, nil}" do
      Application.put_env(:frontend_ex, :backend_version_override, "0.4.4")
      assert Version.backend() == %{version: "0.4.4", sha: nil}
    end

    test "atom-keyed map override passes through" do
      Application.put_env(
        :frontend_ex,
        :backend_version_override,
        %{version: "0.4.4", sha: "abc"}
      )

      assert Version.backend() == %{version: "0.4.4", sha: "abc"}
    end

    test "string-keyed map override is normalized to atom keys" do
      Application.put_env(
        :frontend_ex,
        :backend_version_override,
        %{"version" => "0.4.4", "sha" => "abc"}
      )

      assert Version.backend() == %{version: "0.4.4", sha: "abc"}
    end

    test "malformed override map returns nil instead of raising" do
      Application.put_env(:frontend_ex, :backend_version_override, %{not_version: "oops"})
      assert Version.backend() == nil
    end

    test "override also strips v prefix from the version" do
      Application.put_env(:frontend_ex, :backend_version_override, "v0.4.4")
      assert Version.backend() == %{version: "0.4.4", sha: nil}
    end

    test "unexpected override shapes return nil without crashing" do
      for bad <- [42, [:oops], {:tuple, :value}, :atom, 3.14] do
        Application.put_env(:frontend_ex, :backend_version_override, bad)
        assert Version.backend() == nil, "expected nil for #{inspect(bad)}"
      end
    end
  end
end
