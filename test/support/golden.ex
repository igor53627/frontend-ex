defmodule FrontendEx.TestSupport.Golden do
  @moduledoc false

  import ExUnit.Assertions

  @spec assert_golden!(binary(), binary()) :: :ok
  def assert_golden!(golden_path, actual) when is_binary(golden_path) and is_binary(actual) do
    if update_goldens?() do
      File.mkdir_p!(Path.dirname(golden_path))
      File.write!(golden_path, actual)
      :ok
    else
      expected = File.read!(golden_path)
      assert actual == expected
      :ok
    end
  end

  defp update_goldens? do
    case System.get_env("UPDATE_GOLDENS") do
      "1" -> true
      "true" -> true
      "TRUE" -> true
      "yes" -> true
      "YES" -> true
      _ -> false
    end
  end
end
