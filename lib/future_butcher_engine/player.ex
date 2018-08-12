defmodule FutureButcherEngine.Player do
  alias FutureButcherEngine.{Player, Weapon}

  @enforce_keys [:player_name, :funds, :debt, :rate, :pack, :pack_space, :weapon]
  defstruct     [:player_name, :funds, :debt, :rate, :pack, :pack_space, :weapon]

  @base_space  20
  @cut_keys    [:flank, :heart, :loin, :liver, :ribs]
  @weapon_type [:bat, :brass_knuckles, :knife, :machete]


  # New player ----------------------------------------------------------------

  def new(player_name) when is_binary(player_name) do
    %Player{
      player_name: player_name,
      funds: 0, debt: 0, rate: 0.0,
      pack: initialize_pack(),
      pack_space: @base_space,
      weapon: nil
    }
  end

  def new(_name), do: {:error, :invalid_player_name}

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end


  # Packs ----------------------------------------------------------------------

  def buy_pack(%Player{funds: funds}, _, cost) when funds < cost, do: {:error, :insufficient_funds}

  def buy_pack(%Player{pack_space: current_space}, new_space, _cost)
  when current_space >= new_space, do: {:error, :no_pack_upgrade}

  def buy_pack(player, pack_space, cost) do
    adjust_funds(Map.put(player, :pack_space, pack_space), :decrease, cost)
  end


  # Debt/Loans -----------------------------------------------------------------

  def buy_loan(%Player{debt: debt, rate: rate}, _debt, _rate) when debt > 0 and rate > 0 do
    {:error, :already_has_debt}
  end

  def buy_loan(player, debt, rate) when is_integer(rate) do
    buy_loan(player, debt, rate * 1.0)
  end

  def buy_loan(player, debt, rate) when is_integer(debt) and is_float(rate) do
    player = increase_attribute(player, :debt, debt)
    player = increase_attribute(player, :rate, rate)

    adjust_funds(player, :increase, debt)
  end

  def buy_loan(_player, _debt, _rate) do
    {:error, :invalid_loan_values}
  end

  def accrue_debt(%Player{debt: debt, rate: rate} = player) when debt > 0 do
    new_debt =
      debt |> Kernel.*(1000) |> Kernel.*(rate) |> Kernel./(1000) |> Kernel.round
    {:ok, player |> increase_attribute(:debt, new_debt)}
  end

  def accrue_debt(player), do: {:ok, player}

  def pay_debt(%Player{funds: funds, debt: debt} = player, amount)
  when funds > amount and amount >= debt do
    {:ok, player} = adjust_funds(player, :decrease, debt)
    {:ok, player
          |> decrease_attribute(:debt, debt)
          |> decrease_attribute(:rate, player.rate)}
  end

  def pay_debt(%Player{funds: funds, debt: debt} = player, amount) when funds > amount do
    payoff = Enum.min [debt, amount]
    {:ok, player} = adjust_funds(player, :decrease, payoff)
    {:ok, player |> decrease_attribute(:debt, payoff)}
  end

  def pay_debt(_player, _amount), do: {:error, :insufficient_funds}


  # Buy/Sell Cuts --------------------------------------------------------------

  def buy_cut(%Player{funds: funds}, _cut, _amount, cost) when funds < cost do
    {:error, :insufficient_funds}
  end

  def buy_cut(player, cut, amount, cost) do
    with {:ok} <- sufficient_space?(player, amount) do
      {:ok, player} = adjust_funds(player, :decrease, cost)
      {:ok, player |> Map.put(:pack, increase_cut(player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def sell_cut(player, cut, amount, profit) do
    with {:ok} <- sufficient_cuts?(player.pack, cut, amount) do
      {:ok, player} = adjust_funds(player, :increase, profit)
      {:ok, player |> Map.put(:pack, decrease_cut(player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end


  # Weapons --------------------------------------------------------------------

  def buy_weapon(%Player{weapon: weapon}, _weapon, _cost) when not is_nil(weapon) do
    {:error, :already_owns_weapon}
  end

  def buy_weapon(%Player{funds: funds}, _weapon, cost) when funds < cost do
    {:error, :insufficient_funds}
  end

  def buy_weapon(player, weapon, cost) when weapon in @weapon_type do
    weapon_weight = Weapon.get_weapon_weight(weapon)
    with {:ok} <- sufficient_space?(player, weapon_weight) do
      {:ok, player} = adjust_funds(player, :decrease, cost)
      {:ok, player |> Map.put(:weapon, weapon)}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def buy_weapon(_player, _weapon, _cost), do: {:error, :invalid_weapon_type}

  def replace_weapon(%Player{weapon: weapon}, _weapon, _cost, _value) when is_nil(weapon) do
    {:error, :no_weapon_owned}
  end

  def replace_weapon(%Player{funds: funds}, _weapon, cost, value)
  when Kernel.+(funds, value) < cost, do: {:error, :insufficient_funds}

  def replace_weapon(%Player{weapon: current_weapon}, weapon, _cost, _value)
  when current_weapon == weapon, do: {:error, :same_weapon_type}

  def replace_weapon(player, weapon, cost, value) do
    net_weapon_weight = Weapon.get_weapon_weight(weapon) - Weapon.get_weapon_weight(player.weapon)
    with {:ok} <- sufficient_space?(player, net_weapon_weight) do
      {:ok, player} = adjust_funds(player, :increase, value)
      {:ok, player} = adjust_funds(player, :decrease, cost)
      {:ok, player |> Map.replace!(:weapon, weapon)}
    else
      {:error, msg} -> {:error, msg}
    end
  end


  # Muggings -------------------------------------------------------------------

  def mug_player(%Player{funds: funds}, :funds) when funds == 0 do
    {:error, :insufficient_funds}
  end

  def mug_player(%Player{funds: funds} = player, :funds) do
    funds_penalty = Enum.random(9..16) |> Kernel./(100) |> (fn(n) -> round(funds * n) end).()
    {:ok, player |> decrease_attribute(:funds, funds_penalty)}
  end

  def mug_player(%Player{pack: pack} = player, :cuts) do
    case get_random_cut(pack) do
      {:ok, cut, amount} -> {:ok, player |> Map.put(:pack, decrease_cut(pack, cut, amount))}
      :error             -> {:error, :no_cuts_owned}
    end
  end

  def mug_player(_player, _response), do: {:error, :invalid_mugging_response}


  # Funds ----------------------------------------------------------------------

  def adjust_funds(%Player{funds: funds} = player, :decrease, amount) when amount > funds do
    {:ok, player |> Map.put(:funds, 0)}
  end

  def adjust_funds(player, :decrease, amount) do
    {:ok, player |> decrease_attribute(:funds, amount) }
  end

  def adjust_funds(player, :increase, amount) do
    {:ok, player |> increase_attribute(:funds, amount)}
  end


  # Validations ----------------------------------------------------------------

  defp get_random_cut(pack) do
    owned_cuts = Enum.filter(pack, fn(cut) -> elem(cut, 1) > 0 end)
    case Enum.count(owned_cuts) do
      0  -> :error
      _n ->
        cut_penalty = Enum.random(owned_cuts)
        {:ok, elem(cut_penalty, 0), elem(cut_penalty, 1)}
    end
  end

  defp sufficient_space?(player, amount) do
    space_taken = player.pack
    |> Map.values
    |> Enum.reduce(0, fn(x, acc) -> x + acc end)

    weapon_weight = if player.weapon, do: Weapon.get_weapon_weight(player.weapon), else: 0

    if space_taken + weapon_weight + amount <= player.pack_space do
      {:ok}
    else
      {:error, :insufficient_pack_space}
    end
  end

  defp sufficient_cuts?(pack, cut, amount) do
    if Map.get(pack, cut) >= amount do
      {:ok}
    else
      {:error, :insufficient_cuts}
    end
  end


  # Property updates -----------------------------------------------------------

  defp increase_cut(pack, cut, amount) do
    pack |> Map.put(cut, Map.get(pack, cut) + amount)
  end

  defp decrease_cut(pack, cut, amount) do
    pack |> Map.put(cut, Map.get(pack, cut) - amount)
  end

  defp increase_attribute(player, attribute, amount) do
    player |> Map.put(attribute, Map.get(player, attribute) + amount)
  end

  defp decrease_attribute(player, attribute, amount) do
    player |> Map.put(attribute, Map.get(player, attribute) - amount)
  end

end
