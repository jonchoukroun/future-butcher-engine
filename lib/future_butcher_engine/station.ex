defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Station, Weapon, Pack}

  @enforce_keys [:station_name, :market, :store]
  defstruct [:station_name, :market, :store]

  @stations %{
    :beverly_hills => %{
      :base_crime_rate => 1,
      :travel_time     => 3
      },
    :downtown => %{
      :base_crime_rate => 2,
      :travel_time     => 2
      },
    :venice_beach => %{
      :base_crime_rate => 3,
      :travel_time     => 2
      },
    :hollywood => %{
      :base_crime_rate => 4,
      :travel_time     => 1
      },
    :compton => %{
      :base_crime_rate => 5,
      :travel_time     => 0
      },
    :bell_gardens => %{
      :travel_time => 1
    }
  }

  @station_names [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton, :bell_gardens]

  def station_names, do: @station_names

  def get_base_crime_rate(:bell_gardens), do: {:error, :invalid_station}

  def get_base_crime_rate(station) when station in @station_names do
    @stations[station].base_crime_rate
  end
  def get_base_crime_rate(_station), do: {:error, :invalid_station}

  def new(:bell_gardens, turns_left) when turns_left > 20, do: {:error, :store_not_open}
  def new(:bell_gardens, turns_left) do
    %Station{
      station_name: :bell_gardens,
      store:        generate_store(turns_left),
      market:       nil
    }
  end

  def new(station, _turns_left) when station in @station_names do
    %Station{
      station_name: station,
      market:       generate_market(),
      store:        nil
    }
  end

  def new(_station, _turns_left), do: {:error, :invalid_station}


  # Mugging --------------------------------------------------------------------

  def random_encounter(_pack_space, _turns_left, :bell_gardens), do: {:ok, :end_transit}

  def random_encounter(_pack_space, 0, _station), do: {:ok, :end_transit}

  def random_encounter(pack_space, turns_left, station) do
    p = calculate_mugging_probability(pack_space, turns_left, station)

    case :rand.uniform > p do
      true  -> {:ok, :end_transit}
      false -> {:ok, :mugging}
    end
  end

  def calculate_mugging_probability(20, _turns_left, :compton), do: 0.45
  def calculate_mugging_probability(_pack_space, _turns_left, :compton), do: 0.65

  def calculate_mugging_probability(pack_space, turns_left, station) do
    base_crime_rate = get_base_crime_rate(station)
    current_turn    = 25 - turns_left
    visibility      = if pack_space === 20, do: 0.0, else: 0.1

    :math.sin((current_turn + base_crime_rate) / 35)
    |> :math.pow(6 - base_crime_rate)
    |> Kernel.+(visibility)
    |> Float.round(3)
  end


  # Store ----------------------------------------------------------------------

  def generate_store(turns_left) when turns_left > 20, do: %{}

  def generate_store(turns_left) do
    Enum.concat(generate_weapons_stock(turns_left), generate_packs_stock(turns_left))
    |> Map.new()
  end

  def generate_weapons_stock(turns_left) do
    Weapon.weapon_types
    |> Enum.map(fn weapon -> {weapon, %{
        price:  Weapon.generate_price(weapon, turns_left),
        damage: Weapon.get_damage(weapon),
        cuts:   Weapon.get_cuts(weapon)
        }} end)
  end

  def generate_packs_stock(turns_left) do
    Pack.pack_types
    |> Enum.map(fn pack -> {pack, %{
        price:      Pack.generate_price(pack, turns_left),
        pack_space: Pack.get_pack_space(pack)
        }} end)
  end


  # Market ---------------------------------------------------------------------

  defp generate_market() do
    Map.new(Cut.cut_names(), fn cut -> {cut, generate_cut(cut)} end)
  end

  defp generate_cut(cut) do
    quantity = Enum.random(0..Cut.maximum_quantity(cut))
    %{quantity: quantity, price: get_price(quantity, cut)}
  end

  defp get_price(quantity, cut) when quantity > 0 do
    {:ok, current_price} = Cut.new(cut, quantity)
    current_price.price
  end

  defp get_price(_quantity, _cut), do: nil

end
