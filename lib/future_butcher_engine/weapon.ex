defmodule FutureButcherEngine.Weapon do
  alias FutureButcherEngine.Station

  @weapons %{
    :katana => %{:damage => 10, :min => 100_000, :max => 800_000},
    :machete => %{:damage => 9, :min => 50_000, :max => 400_000},
    :power_claw => %{:damage => 8, :min => 30_000, :max => 240_000},
    :hedge_clippers => %{:damage => 7, :min => 15_000, :max => 120_000},
    :box_cutter => %{:damage => 6, :min => 8_000, :max => 64_000},
  }

  @weapons_list Map.keys(@weapons)

  def weapon_types, do: @weapons_list

  def generate_price(_, turns_left)
    when turns_left > 20, do: nil

  def generate_price(_, turns_left)
    when turns_left < 5, do: nil

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
