defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Station}

  @enforce_keys [:station_name, :market]
  defstruct [:station_name, :market]

  @cuts [:flank, :heart, :liver, :loin, :ribs]
  @stations [:downtown, :venice_beach, :koreatown, :culver_city, :silverlake]

  def new(station) when station in @stations do
    %Station{station_name: station, market: generate_market()}
  end

  def new(_), do: {:error, :invalid_station}

  defp generate_market() do
    Map.new(@cuts, fn type -> {type, generate_cut(type)} end)
  end

  def generate_cut(type) do
    quantity = generate_quantity(type)
    %{quantity: quantity, price: get_price(quantity, type)}
  end

  defp get_price(quantity, type) when quantity > 0 do
    {:ok, current_price} = Cut.new(type, quantity)
    current_price.price
  end

  defp get_price(_quantity, _type), do: nil

  defp generate_quantity(type) do
    Enum.random(0..max_quantities(type))
  end

  defp max_quantities(:flank), do: 20
  defp max_quantities(:heart), do: 10
  defp max_quantities(:liver), do: 100
  defp max_quantities(:loin), do: 45
  defp max_quantities(:ribs), do: 30
  defp max_quantities(_), do: {:error, :invalid_cut_type}
end