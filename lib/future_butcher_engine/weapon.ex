defmodule FutureButcherEngine.Weapon do

  @weapons %{
    :hockey_stick => %{:damage => 9, :can_harvest => false},
    :machete => %{:damage => 7, :can_harvest => true},
    :hedge_clippers => %{:damage => 6, :can_harvest => true},
    :box_cutter => %{:damage => 5, :can_harvest => true},
    :brass_knuckles => %{:damage => 3, :can_harvest => false},
  }

  @weapons_list Map.keys(@weapons)

  def weapon_types, do: @weapons_list

  def generate_price(weapon, turns_left) when weapon in @weapons_list do
    offset = if can_harvest(weapon), do: 1200, else: 600
    offset
    |> Kernel.*(get_damage(weapon))
    |> Kernel./(turns_left + 1)
    |> Kernel.*(200)
    |> round()
  end

  def generate_price(_weapon, _turns_left), do: {:error, :invalid_weapon_type}

  def get_damage(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).damage
  def get_damage(_weapon), do: {:error, :invalid_weapon_type}

  def can_harvest(weapon) when weapon in @weapons_list do
    Map.get(@weapons, weapon).can_harvest
  end
  def can_harvest(_), do: {:error, :invalid_weapon_type}
end
