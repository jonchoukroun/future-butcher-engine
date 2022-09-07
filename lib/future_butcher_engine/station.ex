defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Pack, Station, Weapon}

  @enforce_keys [:station_name, :market, :store, :clinic_cost]
  @derive {Jason.Encoder, only: [:station_name, :market, :store, :clinic_cost]}
  defstruct [:station_name, :market, :store, :clinic_cost]

  @stations %{
    :beverly_hills => %{
      :base_crime_rate => 1,
      :travel_time     => 2,
      :max_adjustment  => 0.5
      },
    :downtown => %{
      :base_crime_rate => 2,
      :travel_time     => 1,
      :max_adjustment  => 0.63
      },
    :venice_beach => %{
      :base_crime_rate => 3,
      :travel_time     => 1,
      :max_adjustment  => 0.75
      },
    :hollywood => %{
      :base_crime_rate => 4,
      :travel_time     => 1,
      :max_adjustment  => 0.88
      },
    :compton => %{
      :base_crime_rate => 5,
      :travel_time     => 1,
      :max_adjustment  => 1.0
      },
    :bell_gardens => %{
      :travel_time => 2
    }
  }

  @station_names [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton, :bell_gardens]

  @clinic_cost 50_000

  @store_open_time 20
  @store_close_time 5

  def station_names, do: @station_names

  def get_clinic_cost, do: @clinic_cost

  def store_open, do: @store_open_time
  def store_close, do: @store_close_time

  def get_base_crime_rate(:bell_gardens), do: {:error, :invalid_station}

  def get_base_crime_rate(station) when station in @station_names do
    @stations[station].base_crime_rate / 40
  end
  def get_base_crime_rate(_station), do: {:error, :invalid_station}

  def get_travel_time(station) when station in @station_names, do: @stations[station].travel_time
  def get_travel_time(_station), do: {:error, :invalid_station}

  def get_max_adjustment(:bell_gardens), do: {:error, :invalid_station}
  def get_max_adjustment(station), do: @stations[station].max_adjustment

  def new(:bell_gardens, turns_left) when turns_left > @store_open_time, do: {:error, :store_not_open}
  def new(:bell_gardnes, turns_left) when turns_left < @store_close_time, do: {:error, :store_not_open}
  def new(:bell_gardens, turns_left) do
    %Station{
      station_name: :bell_gardens,
      store: generate_store(turns_left),
      market: nil,
      clinic_cost: nil
    }
  end

  def new(:venice_beach, _turns_left) do
    %Station{
      station_name: :venice_beach,
      market: nil,
      store: nil,
      clinic_cost: @clinic_cost
    }
  end

  def new(station, _turns_left) when station in @station_names do
    %Station{
      station_name: station,
      market: generate_market(station),
      store: nil,
      clinic_cost: nil
    }
  end

  def new(_station, _turns_left), do: {:error, :invalid_station}


  # Mugging --------------------------------------------------------------------

  def random_encounter(_pack_space, _turns_left, :bell_gardens), do: {:ok, :end_transit}

  def random_encounter(_pack_space, turns_left, _station) when turns_left > 20 do
    {:ok, :end_transit}
  end

  def random_encounter(_pack_space, turns_left, _station) when turns_left === 0 do
    {:ok, :end_transit}
  end

  def random_encounter(pack_space, _turns_left, station) do
    p = calculate_mugging_probability(pack_space, station)

    case :rand.uniform > p do
      true  -> {:ok, :end_transit}
      false -> {:ok, :mugging}
    end
  end

  def calculate_mugging_probability(_, :bell_gardens), do: 0

  def calculate_mugging_probability(pack_space, station) do
    pack_adjustment = (pack_space - 20) / 300
    get_base_crime_rate(station)
    |> Kernel.+(pack_adjustment)
    |> Float.round(3)
  end


  # Store ----------------------------------------------------------------------

  def generate_store(turns_left) when turns_left > @store_open_time, do: %{}
  def generate_store(turns_left) when turns_left < @store_close_time, do: %{}

  def generate_store(turns_left) do
    Enum.concat(generate_weapons_stock(turns_left), generate_packs_stock(turns_left))
    |> Map.new()
  end

  def generate_weapons_stock(turns_left) do
    Weapon.weapon_types
    |> Enum.map(fn weapon -> {weapon, %{
        price: Weapon.generate_price(weapon, turns_left),
        damage: Weapon.get_damage(weapon)
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

  defp generate_market(station) do
    # Generate liver first then ribs as inverse
    liver = generate_cut(:liver, station)
    inverse_quantity = Cut.maximum_quantity(:liver) - liver.quantity;
    ribs = generate_cut(:ribs, inverse_quantity)
    Map.new([:brains, :heart, :flank], fn cut -> {cut, generate_cut(cut, station)} end)
    |> Map.put(:liver, liver)
    |> Map.put(:ribs, ribs)
  end

  defp generate_cut(cut, quantity) when is_integer(quantity) do
    %{quantity: quantity, price: get_price(quantity, cut)}
  end

  defp generate_cut(cut, station) do
    quantity = Enum.random(get_min(station)..get_max(cut, station))
    %{quantity: quantity, price: get_price(quantity, cut)}
  end

  defp get_min(:compton), do: 4
  defp get_min(:hollywood), do: 3
  defp get_min(:downtown), do: 1
  defp get_min(:beverly_hills), do: 0

  defp get_max(cut, station) do
    Cut.maximum_quantity(cut)
    |> Kernel.*(get_max_adjustment(station))
    |> round()
  end

  defp get_price(quantity, cut) do
    {:ok, current_price} = Cut.new(cut, quantity)
    current_price.price
  end

end
