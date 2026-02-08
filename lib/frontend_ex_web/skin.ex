defmodule FrontendExWeb.Skin do
  @moduledoc false

  @type t :: :classic | :s53627

  @spec current() :: t()
  def current do
    case normalize(Application.get_env(:frontend_ex, :ff_skin, "53627")) do
      "classic" -> :classic
      "skin-classic" -> :classic
      "53627" -> :s53627
      "skin-53627" -> :s53627
      _ -> :s53627
    end
  end

  defp normalize(v) when is_binary(v), do: String.trim(v)
  defp normalize(v), do: v |> to_string() |> String.trim()
end
