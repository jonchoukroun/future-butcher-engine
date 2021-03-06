defmodule FutureButcherEngine.Player do
  @moduledoc """
  Player module handles buying/selling cuts, weapons; debt; muggings
  Player modules creates player, handles buying/selling of cuts and weapons, debt management, and muggings.
  """

  alias FutureButcherEngine.{Player, Weapon}

  @enforce_keys [:player_name, :funds, :debt, :pack, :pack_space, :weapon]
  @derive {Jason.Encoder, only: [:player_name, :funds, :debt, :pack, :pack_space, :weapon]}
  defstruct [:player_name, :funds, :debt, :pack, :pack_space, :weapon]

  @base_space 20
  @starter_loan 5000
  @cut_keys [:brains, :heart, :flank, :ribs, :liver]
  @weapon_type [:hedge_clippers, :hockey_stick, :box_cutter, :brass_knuckles, :machete]

  @type player :: %Player{player_name: String.t, funds: integer, debt: integer, pack: map, pack_space: integer, weapon: atom | nil}

  # New player ----------------------------------------------------------------

  @doc """
  Returns a new Player struct with a starting values and an initialized pack.

  Returns an error tuple if `player_name` is invalid.

  ## Examples

      iex > FutureButcherEnging.Player.new("bob")
      %FutureButcherEngine.Player{
        debt: 5000,
        funds: 5000,
        pack: %{brains: 0, flank: 0, heart: 0, liver: 0, ribs: 0},
        pack_space: 20,
        player_name: "bob",
        weapon: nil}

  """
  @spec new(player_name :: String.t) :: player | {:error, atom}
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

  def new(player_name) when not is_binary(player_name), do: {:error, :invalid_player_name}
  def new(_player_name), do: {:error, :invalid_player_name}

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end


  # Packs ----------------------------------------------------------------------

  @doc """
  Returns an updated Player struct with increased pack size and reduced funds.

  Returns an error tuple if either the pack cost is greater than player funds, or
  the new pack size is not greater than the current pack size.

  ## Examples

      iex > FutureButcherEngine.Player.buy_pack(%Player{funds: 5000, pack_space: 20, ...}, 30, 1000)
      {:ok, FutureButcherEngine.Player%{funds: 4000, pack_space: 30, ...}}

      iex > FutureButcherEngine.Player.buy_pack(%Player{funds: 1000, ...}, 30, 2000)
      {:error, :insufficient_funds}

      iex > FutureButcherEngine.Player.buy_pack(%Player{pack_space: 30, ...}, 20, 1000)
      {:error, :must_upgrade_pack}
  """
  @spec buy_pack(player, funds :: integer, cost :: integer) :: {:ok, player} | {:error, atom}
  def buy_pack(%Player{funds: funds}, _, cost) when funds < cost, do: {:error, :insufficient_funds}

  def buy_pack(%Player{pack_space: current_space}, new_space, _cost)
  when current_space >= new_space, do: {:error, :must_upgrade_pack}

  def buy_pack(player, pack_space, cost) do
    adjust_funds(Map.put(player, :pack_space, pack_space), :decrease, cost)
  end


  # Debt/Loans -----------------------------------------------------------------

  @doc """
  Returns an updated Player struct with a higher debt amount. Debt increases by 5% each turn.

  Returns an unchanged Player struct when debt is 0.

  ## Examples

      iex > FutureButcherEngine.Player.accrue_debt(%Player{debt: 5000, ...}, 5)
      {:ok, %FutureButcherEngine.Player{debt: 6381, ...}}
  """
  @spec accrue_debt(player, turns :: integer) :: {:ok, player} | {:error, atom}
  def accrue_debt(%Player{debt: debt} = player, turns) when debt > 0 do
    accrued_debt = debt * :math.pow(1.05, turns) |> round()
    {:ok, %Player{player | debt: accrued_debt}}
  end

  def accrue_debt(player, _turns), do: {:ok, player}

  @doc """
  Returns an updated Player struct with zeroed-out debt and decreased funds.

  Returns an error tuple if the debt amount to repay is greater than player funds.

  ## Examples

      iex > FutureButcherEngine.Player.pay_debt(%Player{debt: 5000, funds: 7000 ...})
      {:ok, %FutureButcherEngine.Player{debt: 0, funds: 2000, ...}}
  """
  @spec pay_debt(player) :: {:ok, player} | {:error, atom}
  def pay_debt(%Player{funds: f, debt: d}) when d > f, do: {:error, :insufficient_funds}

  def pay_debt(player) do
    {:ok, paid_player} = adjust_funds(player, :decrease, player.debt)
    {:ok, %Player{paid_player | debt: 0}}
  end


  # Buy/Sell Cuts --------------------------------------------------------------

  @doc """
  Returns an updated Player struct with reduced funds and an increased cut in the pack map.

  Returns an error tuple if the buy cost is greater than player funds.

  ## Examples

      iex > FutureButcherEngine.Player.buy_cut(%Player{funds: 5000, pack: %{}, ...}, :heart, 5, 1000)
      {:ok, %FutureButcherEngine.Player{funds: 4000, pack: %{heart: 5}, ...}}
  """
  @spec buy_cut(player, cut :: atom, amount :: integer, cost :: integer) :: {:ok, player} | {:error, atom}
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

  @doc """
  Returns an updated Player struct with increased funds and a reduced cut in the pack map.

  Returns an error tuple if the sell amount is greater than the cut owned.

  ## Examples

      iex > FutureButcherEngine.Player.sell_cut(%Player{funds: 5000, pack: %{heart: 5}, ...}, :heart, 3, 1000)
      {:ok, %FutureButcherEngine.Player{funds: 5000, pack: %{heart: 2}, ...}}
  """
  @spec sell_cut(player, cut :: atom, amount :: integer, profit :: integer) :: {:ok, player} | {:error, atom}
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
  Returns an updated Player struct with a new weapon and adjusted funds.

  Returns an error tuple if weapon cost is greater than player funds, or player already owns weapon.

  ## Examples

      iex > FutureButcherEngine.Player.buy_weapon(%Player{funds: 5000, weapon: nil, ...}, :axe, 1000)
      {:ok, %FutureButcherEngine.Player{funds: 4000, weapon: :axe, ...}}

      iex > FutureButcherEngine.Player.buy_weapon(%Player{funds: 5000, weapon: :knife, ...}, :axe, 1000)
      {:error, :already_owns_weapon}

      iex > FutureButcherEngine.Player.buy_weapon(%Player{funds: 1000, weapon: nil, ...}, :axe, 2000)
      {:error, :insufficient_funds}
  """
  @spec buy_weapon(player, weapon :: atom, cost :: integer) :: {:ok, player} | {:error, atom}
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
  Returns an updated Player struct with a different weapon and adjusted funds.
  """
  @spec replace_weapon(player, weapon :: atom, cost :: integer, value :: integer) :: {:ok, player} | {:error, atom}
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

  @doc """
  Returns an updated Player struct with no weapon, or returns an error tuple if no weapon is owned.
  """
  @spec drop_weapon(player) :: {:ok, player} | {:error, atom} 
  def drop_weapon(%Player{weapon: nil}), do: {:error, :no_weapon_owned}
  def drop_weapon(player), do: {:ok, player |> Map.replace!(:weapon, nil)}


  # Muggings -------------------------------------------------------------------

  @doc """
  Returns an updated Player struct adjusted on the outcome of the fight.

    ## Examples

        iex > FutureButcherEngine.Player.fight_mugger(%Player{weapon: nil, ...})
        {:ok, %FutureButcherEngine.Player{...}, :defeat}

        iex > FutureButcherEngine.Player.fight_mugger(%Player{pack: %{heart: 1, ...}, weapon: :machete, ...})
        {:ok, %FutureButcherEngine.Player{pack: %{heart: 2}}, :victory}
  """
  @spec fight_mugger(player) :: {:ok, player, outcome :: atom}
  def fight_mugger(%Player{weapon: nil} = player), do: {:ok, player, :defeat}

  def fight_mugger(player) do
    case Weapon.get_damage(player.weapon) >= Enum.random(1..10) do
      true ->
        harvest = harvest_mugger(player)
        |> Enum.reduce(player.pack, fn cut, pack -> increase_cut(pack, cut, 1) end)
        {:ok, player |> Map.put(:pack, harvest), :victory}
      false ->
        {:ok, player, :defeat}
    end
  end

  @doc """
  Returns an adjusted Player struct with either funds reduced by 10 to 30% if player funds exceed $500, or
  an owned cut zeroed out.

  Returns an error tuple if player funds are under $500 and no cuts are owned.
  """
  @spec bribe_mugger(player) :: {:ok, player} | {:error, atom}
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

  @doc """
  Returns an adjusted Player struct with funds increased or decreased by the passed in amount.

    ## Examples

        iex > FutureButcherEngine.Player.adjust_funds(%Player{funds: 5000, ...}, :increase, 1000)
        %FutureButcherEngine.Player{funds: 6000, ...}

        iex > FutureButcherEngine.Player.adjust_funds(%Player{funds: 5000, ...}, :decrease, 1000)
        %FutureButcherEngine.Player{funds: 4000, ...}
  """
  @spec adjust_funds(player, direction :: atom, amount :: integer) :: {:ok, player}
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
    |> Enum.reject(fn _cut -> Enum.random(1..10) > 5 end)
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
