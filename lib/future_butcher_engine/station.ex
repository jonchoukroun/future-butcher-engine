defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Station, Weapon, Pack}

  @enforce_keys [:station_name, :market, :store]
  defstruct [:station_name, :market, :store]

  @stations %{
    :beverly_hills => %{ :base_crime_rate => 1 },
    :downtown      => %{ :base_crime_rate => 2 },
    :venice_beach  => %{ :base_crime_rate => 3 },
    :hollywood     => %{ :base_crime_rate => 4 },
    :compton       => %{ :base_crime_rate => 5 }
  }

  @station_names [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton]

  def station_names, do: @station_names

  def get_base_crime_rate(station) when station in @station_names do
    @stations[station].base_crime_rate
  end
  def get_base_crime_rate(_station), do: {:error, :invalid_station}

  def new(station, turns_left) when station == :venice_beach do
    %Station{
      station_name: station,
      market:       generate_market(station, turns_left),
      store:        generate_store(turns_left)
    }
  end

  def new(station, turns_left) when station in @station_names do
    %Station{
      station_name: station,
      market:       generate_market(station, turns_left),
      store:        nil
    }
  end

  def new(_station, _turns_left), do: {:error, :invalid_station}

  # Entry fee ------------------------------------------------------------------

  def generate_entry_fee(:compton, _turns_left), do: {:ok, 0}

  def generate_entry_fee(station, turns_left) do
    crime_rate   = get_base_crime_rate(station)
    current_turn = 25 - turns_left
    {:ok, (:math.pow(current_turn, 3) / crime_rate) + (5000 / crime_rate) |> round()}
  end

  def generate_entry_fee(_station, _turns_left), do: {:error, :invalid_entry_fee_inputs}

  # Mugging --------------------------------------------------------------------

  def random_encounter(_space, turns_left, _station) when turns_left === 0, do: {:ok, :end_transit}

  def random_encounter(pack_space, turns_left, station) do
    base_crime_rate       = get_base_crime_rate(station)
    current_turn          = 25 - turns_left
    visibility_adjustment = (pack_space - 20) / 500

    p = :math.sin((current_turn + base_crime_rate) / 25)
        |> :math.pow(9 - base_crime_rate)
        |> Kernel.+(visibility_adjustment)
        |> Float.round(3)

    case :rand.uniform > p do
      true  -> {:ok, :end_transit}
      false -> {:ok, :mugging}
    end
  end


  # Store ----------------------------------------------------------------------

  def generate_store(turns_left) when turns_left > 18, do: %{}

  def generate_store(turns_left) when turns_left <= 12 do
    generate_weapons_stock(turns_left)
    |> Enum.concat(generate_packs_stock(turns_left))
    |> Map.new()
  end

  def generate_store(turns_left) do
    generate_weapons_stock(turns_left)
    |> Map.new()
  end

  def generate_weapons_stock(turns_left) do
    select_available_stock(Weapon.weapon_types)
    |> Enum.map(fn weapon -> {weapon, %{
        price:  Weapon.generate_price(weapon, turns_left),
        weight: Weapon.get_weight(weapon)
        }} end)
  end

  def generate_packs_stock(turns_left) do
    select_available_stock(Pack.pack_types)
    |> Enum.map(fn pack -> {pack, %{
        price:      Pack.generate_price(pack, turns_left),
        pack_space: Pack.get_pack_space(pack)
        }} end)
  end

  defp select_available_stock(inventory) do
    inventory
    |> Enum.reject(fn _item -> Enum.random(1..10) < 6 end)
  end


  # Market ---------------------------------------------------------------------

  defp generate_market(station, turns_left) do
    Map.new(Cut.cut_names, fn cut -> {cut, generate_cut(cut, station, turns_left)} end)
  end

  defp generate_cut(cut, station, turns_left) do
    quantity = generate_quantity(cut, station, turns_left)
    %{quantity: quantity, price: get_price(quantity, cut)}
  end

  defp generate_quantity(cut, station, turns_left) do
    base_max = Cut.maximum_quantity(cut)
    range    = generate_adjusted_range(station, turns_left)
    max      = base_max - (base_max * ((1 - range) / 2)) |> round()
    min      = base_max * ((1 - range) / 2) + 1 |> round()
    Enum.random(min..max)
  end

  defp generate_adjusted_range(station, turns_left) when turns_left > 20 do
    validate_range_value((0.1 * @stations[station].base_crime_rate) + 0.5)
  end

  defp generate_adjusted_range(station, turns_left) when turns_left > 15 do
    validate_range_value((0.1 * @stations[station].base_crime_rate) + 0.6)
  end

  defp generate_adjusted_range(station, turns_left) when turns_left > 10 do
    validate_range_value((0.1 * @stations[station].base_crime_rate) + 0.7)
  end

  defp generate_adjusted_range(station, turns_left) when turns_left > 5 do
    validate_range_value((0.1 * @stations[station].base_crime_rate) + 0.8)
  end

  defp generate_adjusted_range(station, turns_left) when turns_left <= 5 do
    validate_range_value((0.1 * @stations[station].base_crime_rate) + 0.9)
  end

  defp generate_adjusted_range(_station, _turns_left), do: {:error, :invalid_station_values}

  defp validate_range_value(range) when range > 1, do: 1.0
  defp validate_range_value(range), do: range

  defp get_price(quantity, cut) when quantity > 0 do
    {:ok, current_price} = Cut.new(cut, quantity)
    current_price.price
  end

  defp get_price(_quantity, _cut), do: nil

end
