defmodule FutureButcherEngine.Weapon do

  @weapons %{
    :hockey_stick => %{:damage => 10, :can_harvest => false},
    :machete => %{:damage => 7, :can_harvest => true},
    :hedge_clippers => %{:damage => 6, :can_harvest => true},
    :box_cutter => %{:damage => 5, :can_harvest => true},
    :brass_knuckles => %{:damage => 5, :can_harvest => false},
  }

  @weapons_list Map.keys(@weapons)

  def weapon_types, do: @weapons_list

  def generate_price(weapon, turns_left) when weapon in @weapons_list do
    harvest_offset = if can_harvest(weapon), do: 1.2, else: 1
    damage_discount = 10 - get_damage(weapon) |> Kernel.*(16_000)
    (100_000 - damage_discount)
    |> Kernel./(turns_left + 1)
    |> Kernel.*(22 * harvest_offset )
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
