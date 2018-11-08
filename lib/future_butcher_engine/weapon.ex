defmodule FutureButcherEngine.Weapon do

  @weapons %{
    :hockey_stick   => %{:damage => 8, :cuts => []},
    :machete        => %{:damage => 7, :cuts => [:ribs, :liver, :flank, :brains]},
    :hedge_clippers => %{:damage => 6, :cuts => [:ribs, :flank, :liver, :heart]},
    :brass_knuckles => %{:damage => 5, :cuts => []},
    :box_cutter     => %{:damage => 4, :cuts => [:brains, :heart, :liver, :flank]}
  }

  @weapons_list Map.keys(@weapons)

  def weapon_types, do: @weapons_list

  def generate_price(weapon, turns_left) when weapon in @weapons_list do
    Enum.count(get_cuts(weapon))
    |> Kernel.+(1)
    |> Kernel.*(get_damage(weapon))
    |> Kernel./(turns_left + 1)
    |> Kernel.*(15000)
    |> round()
  end

  def generate_price(_weapon, _turns_left), do: {:error, :invalid_weapon_type}

  def get_damage(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).damage
  def get_damage(_weapon), do: {:error, :invalid_weapon_type}

  def get_cuts(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).cuts
  def get_cuts(_weapon), do: {:error, :invalid_weapon_type}

end
