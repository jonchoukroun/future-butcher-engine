defmodule FutureButcherEngine.Station do
  alias FutureButcherEngine.{Cut, Station, Weapon, Pack}

  @enforce_keys [:station_name, :market, :store]
  defstruct [:station_name, :market, :store]

  @stations %{
    :beverly_hills => %{
      :base_crime_rate => 1,
      :cuts_list => [:heart, :flank]
    },
    :downtown => %{
      :base_crime_rate => 2,
      :cuts_list => [:heart, :flank, :ribs]
    },
    :venice_beach => %{
      :base_crime_rate => 3,
      :cuts_list => [:ribs, :loin, :liver]
    },
    :hollywood => %{
      :base_crime_rate => 4,
      :cuts_list => [:loin, :liver]
    },
    :compton => %{
      :base_crime_rate => 5,
      :cuts_list => Cut.cut_names
    }
  }

  @station_names [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton]

  def station_names, do: @station_names

  def station_cuts(station), do: @stations[station].cuts_list

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


  # Banking --------------------------------------------------------------------

  def validate_station(:downtown, :loans), do: {:ok}
  def validate_station(_station, :loans), do: {:error, :must_be_downtown}


  # Entry fee ------------------------------------------------------------------

  def generate_entry_fee(:compton, _turns_left), do: {:ok, 0}

  def generate_entry_fee(station, turns_left) do
    crime_rate   = get_base_crime_rate(station)
    current_turn = 25 - turns_left
    fee = 2 * (5 - crime_rate) * :math.pow(current_turn, 2) - (100 * crime_rate) + 500 |> round()
    {:ok, fee}
  end


  # Mugging --------------------------------------------------------------------

  def random_encounter(_space, turns_left, _station) when turns_left === 0, do: {:ok, :end_transit}

  def random_encounter(pack_space, turns_left, station) do
    p = calculate_mugging_probability(pack_space, turns_left, station)

    case :rand.uniform > p do
      true  -> {:ok, :end_transit}
      false -> {:ok, :mugging}
    end
  end

  def calculate_mugging_probability(20, _turns_left, :compton), do: 0.55
  def calculate_mugging_probability(_pack_space, _turns_left, :compton), do: 0.7

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
    Map.new(station_cuts(station), fn cut -> {cut, generate_cut(cut, station, turns_left)} end)
  end

  defp generate_cut(cut, station, turns_left) do
    quantity = Enum.random(0..Cut.maximum_quantity(cut))
    %{quantity: quantity, price: get_price(quantity, cut)}
  end

  defp get_price(quantity, cut) when quantity > 0 do
    {:ok, current_price} = Cut.new(cut, quantity)
    current_price.price
  end

  defp get_price(_quantity, _cut), do: nil

end
