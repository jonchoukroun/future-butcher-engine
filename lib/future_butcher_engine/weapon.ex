defmodule FutureButcherEngine.Weapon do
  alias __MODULE__

  @weapons %{
    :brass_knuckles => %{:damage => 3, :weight => 1},
    :blackjack      => %{:damage => 6, :weight => 3},
    :bat            => %{:damage => 7, :weight => 5},
    :machete        => %{:damage => 9, :weight => 2},
    :axe            => %{:damage => 8, :weight => 4}
  }

  @weapons_list Map.keys(@weapons)

  def weapon_names, do: @weapons_list

  # def weapons_stats(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon)

  def generate_price(weapon, turns_left) when weapon in @weapons_list do
    weapon_stats = Map.get(@weapons, weapon)
    :math.pow(2, (weapon_stats.damage / turns_left)) / weapon_stats.weight
    |> Kernel.*(50)
    |> round()
  end

  def get_price(_weapon, _turns_left), do: {:error, :invalid_weapon_type}

  def get_damage(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).damage
  def get_damage(_weapon), do: {:error, :invalid_weapon_type}

  def get_weight(weapon) when weapon in @weapons_list, do: Map.get(@weapons, weapon).weight
  def get_weight(_weapon), do: {:error, :invalid_weapon_type}

end
