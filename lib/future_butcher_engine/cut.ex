defmodule FutureButcherEngine.Cut do
  alias __MODULE__

  defstruct [:type, :price]

  def new(type, quantity) do
    cut_values = %{type: type, price: calculate_price(type, quantity)}
    {:ok, struct(Cut, cut_values)}
  end

  defp calculate_price(type, quantity) do
    values = cut_values(type)
    round((elem(values, 0) * quantity) + elem(values, 1))
  end

  defp cut_values(:flank), do: {-450.0, 14_000}
  defp cut_values(:heart), do: {-1000.0, 25_000}
  defp cut_values(:liver), do: {-0.55, 65}
  defp cut_values(:loin), do: {-17.0, 1300}
  defp cut_values(:ribs), do: {-83.0, 3500}
  defp cut_values(_), do: {:error, :invalid_cut_type}
end