defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Station}

  @enforce_keys [:name, :market]
  defstruct [:name, :market]

  @cuts [:flank, :heart, :liver, :loin, :ribs]

  def new(name) do
    {:ok, %Station{name: name, market: generate_market()}}
  end

  def generate_market() do
    Enum.map(@cuts, fn type -> generate_cut(type) end)
    |> Enum.reject(fn cut ->
        Map.values(cut) |> List.first |> Map.get(:price) == nil end)
  end

  def generate_cut(type) do
    quantity = generate_quantity(type)
    %{type => %{quantity: quantity, price: get_price(quantity, type)}}
  end

  def get_price(quantity, type) when quantity > 0 do
    {:ok, current_price} = Cut.new(type, quantity)
    current_price.price
  end

  def get_price(_, type), do: nil

  def generate_quantity(type) do
    Enum.random(0..max_quantities(type))
  end

  defp max_quantities(:flank), do: 20
  defp max_quantities(:heart), do: 10
  defp max_quantities(:liver), do: 100
  defp max_quantities(:loin), do: 45
  defp max_quantities(:ribs), do: 30
  defp max_quantities(_), do: {:error, :invalid_cut_type}
end