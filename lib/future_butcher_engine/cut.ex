defmodule FutureButcherEngine.Cut do
  alias __MODULE__

  defstruct [:type, :price]

  def new(type, quantity) do
    # {:ok, %Cut{type: type, price: calculate_price(type, quantity)}}

    case calculate_price(type, quantity) do
      {:error, msg} ->
        {:error, msg}
      cut_price ->
        {:ok, %Cut{type: type, price: cut_price}}
    end
  end

  defp calculate_price(type, quantity) do
    case cut_values(type, quantity) do
      {:error, msg} ->
        {:error, msg}
      {slope, max_price} ->
        round((slope * quantity) + max_price)
    end
  end

  defp cut_values(:flank, quantity) when quantity <= 20, do: {-450.0, 14_000}
  defp cut_values(:heart, quantity) when quantity <= 10, do: {-1000.0, 25_000}
  defp cut_values(:liver, quantity) when quantity <= 100, do: {-0.55, 65}
  defp cut_values(:loin, quantity) when quantity <= 45, do: {-17.0, 1300}
  defp cut_values(:ribs, quantity) when quantity <= 30, do: {-83.0, 3500}
  defp cut_values(_, quantity), do: {:error, "#{quantity} exceeds cut maximum"}
end