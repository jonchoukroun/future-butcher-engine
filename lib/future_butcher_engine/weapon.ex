defmodule FutureButcherEngine.Weapon do

  @weapons %{
    :katana => %{:damage => 10, :min => 100_000, :max => 800_000},
    :machete => %{:damage => 9, :min => 60_000, :max => 480_000},
    :power_claw => %{:damage => 8, :min => 30_000, :max => 240_000},
    :hedge_clippers => %{:damage => 7, :min => 20_000, :max => 160_000},
    :box_cutter => %{:damage => 6, :min => 15_000, :max => 120_000},
  }

  @weapons_list Map.keys(@weapons)

  def weapon_types, do: @weapons_list

  def generate_price(weapon, turns_left)
    when weapon in @weapons_list do
      time = Station.store_close() - Station.store_open()
      min = get_in(@weapons, [weapon, :min])
      max = get_in(@weapons, [weapon, :max])
      slope = (max - min) / time
      intercept = max - (slope * Station.store_close())

      (slope * turns_left + intercept) |> round()
    end

  def generate_price(_weapon, _turns_left), do: {:error, :invalid_weapon_type}

  def get_damage(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).damage
  def get_damage(_weapon), do: {:error, :invalid_weapon_type}
end
