defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Station}

  @enforce_keys [:station_name, :market]
  defstruct [:station_name, :market]

  @stations [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton]

  def station_names, do: @stations

  def new(station, turns_left) when station in @stations do
    %Station{
      station_name: station,
      market: generate_market(station, turns_left),
    }
  end

  def new(_), do: {:error, :invalid_station}

  def generate_market(station, turns_left) do
    Map.new(Cut.cut_names, fn cut -> {cut, generate_cut(cut, station, turns_left)} end)
  end

  def generate_cut(cut, station, turns_left) do
    quantity = generate_quantity(cut, station, turns_left)
    %{quantity: quantity, price: get_price(quantity, cut)}
  end

  def generate_quantity(cut, station, turns_left) do
    base_max = Cut.maximum_quantity(cut)
    range    = get_adjusted_range(station, turns_left)
    max      = base_max - (base_max * ((1 - range) / 2)) |> round()
    min      = base_max * ((1 - range) / 2) + 1 |> round()
    Enum.random(min..max)
  end

  def get_adjusted_range(:beverly_hills, turns_left) do
    cond do
      turns_left > 20 -> 0.6
      turns_left > 15 -> 0.7
      turns_left > 10 -> 0.8
      turns_left > 5  -> 0.9
      turns_left <= 5 -> 1.0
    end
  end
  def get_adjusted_range(:downtown, turns_left) do
    cond do
      turns_left > 20   -> 0.7
      turns_left > 15   -> 0.8
      turns_left > 10   -> 0.9
      turns_left <= 10  -> 1.0
    end
  end

  def get_adjusted_range(:venice_beach, turns_left) do
    cond do
      turns_left > 20  -> 0.8
      turns_left > 15  -> 0.9
      turns_left <= 15 -> 1.0
    end
  end

  def get_adjusted_range(:hollywood, turns_left) do
    cond do
      turns_left > 20 -> 0.9
      turns_left <= 15 -> 1.0
    end
  end

  def get_adjusted_range(:compton, _turns_left), do: 1.0

  def get_adjusted_range(_station, _turns_left), do: {:error, :invalid_station_name}

  def get_price(quantity, cut) when quantity > 0 do
    {:ok, current_price} = Cut.new(cut, quantity)
    current_price.price
  end

  def get_price(_quantity, _cut), do: nil

end
