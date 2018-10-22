defmodule FutureButcherEngine.Player do
  @moduledoc """
  Player module handles buying/selling cuts, weapons; debt; muggings
  """

  alias FutureButcherEngine.{Player, Weapon}

  @enforce_keys [:player_name, :funds, :debt, :pack, :pack_space, :weapon]
  defstruct     [:player_name, :funds, :debt, :pack, :pack_space, :weapon]

  @base_space   20
  @starter_loan 5000
  @cut_keys     [:flank, :heart, :loin, :liver, :ribs]
  @weapon_type  [:hedge_clippers, :hockey_stick, :box_cutter, :brass_knuckles, :machete]


  # New player ----------------------------------------------------------------

  @doc """
  .new/1: player name
  """
  def new(player_name) when is_binary(player_name) do
    %Player{
      player_name: player_name,
      funds:       @starter_loan,
      debt:        @starter_loan,
      pack:        initialize_pack(),
      pack_space:  @base_space,
      weapon:      nil
    }
  end

  def new(_name), do: {:error, :invalid_player_name}

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end


  # Packs ----------------------------------------------------------------------

  @doc """
  .buy_pack/3: player, space of new pack, cost of new pack
  """
  def buy_pack(%Player{funds: funds}, _, cost) when funds < cost, do: {:error, :insufficient_funds}

  def buy_pack(%Player{pack_space: current_space}, new_space, _cost)
  when current_space >= new_space, do: {:error, :must_upgrade_pack}

  def buy_pack(player, pack_space, cost) do
    adjust_funds(Map.put(player, :pack_space, pack_space), :decrease, cost)
  end


  # Debt/Loans -----------------------------------------------------------------

  @doc """
  .accrue_debt/2: player, turns
  """
  def accrue_debt(%Player{debt: debt} = player, turns) when debt > 0 do
    accrued_debt = debt * :math.pow(1.05, turns) |> round()
    {:ok, %Player{player | debt: accrued_debt}}
  end

  def accrue_debt(player, _turns), do: {:ok, player}

  @doc """
  .pay_debt/1: player
  """
  def pay_debt(%Player{funds: f, debt: d}) when d > f, do: {:error, :insufficient_funds}

  def pay_debt(player) do
    {:ok, paid_player} = adjust_funds(player, :decrease, player.debt)
    {:ok, %Player{paid_player | debt: 0}}
  end


  # Buy/Sell Cuts --------------------------------------------------------------

  @doc """
  .buy_cut/4: player, cut name, cut amount, cut cost
  """
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

  @doc """
  .buy_weapon/3: player, weapon name, weapon cost
  """
  def buy_weapon(%Player{weapon: weapon}, _weapon, _cost) when not is_nil(weapon) do
    {:error, :already_owns_weapon}
  end

  def buy_weapon(%Player{funds: funds}, _weapon, cost) when funds < cost do
    {:error, :insufficient_funds}
  end

  def buy_weapon(player, weapon, cost) when weapon in @weapon_type do
    {:ok, player} = adjust_funds(player, :decrease, cost)
    {:ok, player |> Map.put(:weapon, weapon)}
  end

  def buy_weapon(_player, _weapon, _cost), do: {:error, :invalid_weapon_type}


  @doc """
  .replace_weapon/4: player, new weapon name, new weapon cost, current weapon value
  """
  def replace_weapon(%Player{weapon: weapon}, _weapon, _cost, _value) when is_nil(weapon) do
    {:error, :no_weapon_owned}
  end

  def replace_weapon(%Player{funds: funds}, _weapon, cost, value)
  when Kernel.+(funds, value) < cost, do: {:error, :insufficient_funds}

  def replace_weapon(%Player{weapon: current_weapon}, weapon, _cost, _value)
  when current_weapon == weapon, do: {:error, :same_weapon_type}

  def replace_weapon(player, weapon, cost, value) do
    {:ok, player} = adjust_funds(player, :increase, value)
    {:ok, player} = adjust_funds(player, :decrease, cost)
    {:ok, player |> Map.replace!(:weapon, weapon)}
  end

  def drop_weapon(%Player{weapon: nil}), do: {:error, :no_weapon_owned}
  def drop_weapon(player), do: {:ok, player |> Map.replace!(:weapon, nil)}


  # Muggings -------------------------------------------------------------------

  def fight_mugger(%Player{weapon: nil} = player), do: {:ok, player, :defeat}

  def fight_mugger(player) do
    case Weapon.get_damage(player.weapon) <= Enum.random(1..10) do
      true ->
        harvest = harvest_mugger(player)
        |> Enum.reduce(player.pack, fn cut, pack -> increase_cut(pack, cut, 1) end)
        {:ok, player |> Map.put(:pack, harvest), :victory}
      false ->
        {:ok, player, :defeat}
    end
  end

  def bribe_mugger(%Player{funds: funds} = player) when funds >= 500 do
    loss = Enum.random(10..30) |> Kernel./(100) |> (fn n -> round(funds * n) end).()
    adjust_funds(player, :decrease, loss)
  end

  def bribe_mugger(%Player{pack: pack} = player) do
    case get_random_cut(pack) do
      {:ok, cut, amount} -> {:ok, player |> Map.put(:pack, decrease_cut(pack, cut, amount))}
                  :error -> {:error, :cannot_bribe_mugger}
    end
  end


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

  defp get_weight_carried(player) do
    player.pack
    |> Map.values()
    |> Enum.reduce(0, fn cut, acc -> cut + acc end)
  end

  defp sufficient_space?(player, amount) do
    if get_weight_carried(player) + amount <= player.pack_space do
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

  defp harvest_mugger(player) do
    Weapon.get_cuts(player.weapon)
    |> Enum.reject(fn _cut -> Enum.random(0..10) >= 4 end)
    |> Enum.map_reduce(get_weight_carried(player), fn cut, acc ->
      {(if player.pack_space > acc, do: cut), (acc + 1)} end)
    |> elem(0)
    |> Enum.reject(fn cut -> is_nil(cut) end)
  end

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
