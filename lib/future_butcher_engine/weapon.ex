defmodule FutureButcherEngine.Weapon do

  @weapons %{
    :hedge_clippers => %{:damage => 5, :weight => 3, :cuts => [:ribs, :flank, :liver, :heart]},
    :hockey_stick   => %{:damage => 8, :weight => 5, :cuts => []},
    :brass_knuckles => %{:damage => 4, :weight => 1, :cuts => []},
    :box_cutter     => %{:damage => 3, :weight => 1, :cuts => [:loin, :heart, :liver, :flank]},
    :machete        => %{:damage => 7, :weight => 2, :cuts => [:ribs, :loin, :flank]}
  }

  @weapons_list Map.keys(@weapons)

  def weapon_types, do: @weapons_list

  def generate_price(weapon, turns_left) when weapon in @weapons_list do
    Enum.count(get_cuts(weapon))
    |> Kernel.+(1)
    |> Kernel.*(get_damage(weapon))
    |> Kernel./(get_weight(weapon) / 2)
    |> Kernel./(turns_left)
    |> Kernel.*(8000)
    |> round()
  end

  def generate_price(_weapon, _turns_left), do: {:error, :invalid_weapon_type}

  def get_damage(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).damage
  def get_damage(_weapon), do: {:error, :invalid_weapon_type}

  def get_weight(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).weight
  def get_weight(_weapon), do: {:error, :invalid_weapon_type}

  def get_cuts(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).cuts
  def get_cuts(_weapon), do: {:error, :invalid_weapon_type}

end
