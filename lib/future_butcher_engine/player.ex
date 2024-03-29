defmodule FutureButcherEngine.Player do
  @moduledoc """
  Player modules creates player, handles buying/selling of cuts and weapons, debt and health management, and muggings.
  """

  alias FutureButcherEngine.{Player, Station, Weapon}

  @enforce_keys [:player_name, :cash, :debt, :has_oil, :health, :pack, :pack_space, :weapon]
  @derive {
    Jason.Encoder, only: [
      :player_name, :cash, :debt, :has_oil, :health, :pack, :pack_space, :weapon
    ]
  }
  defstruct [:player_name, :cash, :debt, :has_oil, :health, :pack, :pack_space, :weapon]

  @base_space 20
  @starter_loan 5000
  @full_health 100
  @loan_rate 0.15
  @cut_keys [:brains, :heart, :flank, :ribs, :liver]
  @weapon_type [:hedge_clippers, :katana, :box_cutter, :power_claw, :machete]

  @type player :: %Player{
    player_name: String.t,
    cash: integer,
    debt: integer,
    has_oil: boolean,
    health: integer,
    pack: map,
    pack_space: integer,
    weapon: atom | nil
  }

  # New player ----------------------------------------------------------------

  @doc """
  Returns a new Player struct with starting values and an initialized pack.

  Returns an error tuple if `player_name` is invalid.

  ## Examples

      iex > FutureButcherEnging.Player.new("bob")
      %FutureButcherEngine.Player{
        cash: 5000,
        debt: 5000,
        has_oil: false,
        health: 100,
        pack: %{brains: 0, flank: 0, heart: 0, liver: 0, ribs: 0},
        pack_space: 20,
        player_name: "bob",
        weapon: nil
      }

  """
  @spec new(player_name :: String.t) :: player | {:error, atom}
  def new(player_name) when is_binary(player_name) do
    %Player{
      cash: @starter_loan,
      debt: @starter_loan,
      has_oil: false,
      health: @full_health,
      pack: initialize_pack(),
      pack_space: @base_space,
      player_name: player_name,
      weapon: nil
    }
  end

  def new(player_name) when not is_binary(player_name), do: {:error, :invalid_player_name}
  def new(_player_name), do: {:error, :invalid_player_name}

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end


  # Health ---------------------------------------------------------------------

  @doc """
  Returns an updated Player struct with the health field decreased by the
  passed-in amount.

  ## Examples

      iex > FutureButcherEngine.Player.decrease_health(%Player{health: 20}, 30)
      {:ok, FutureButcherEngine.Player%{health: -10, ...}}
  """
  @spec decrease_health(player, amount :: integer) :: {:ok, player} | {:error, atom}
  def decrease_health(_player), do: {:error, :missing_damage_amount}
  def decrease_health(player, amount) when amount == 0, do: {:ok, player}
  def decrease_health(%Player{health: health} = player, amount) do
    {:ok, %Player{player | health: health - amount}}
  end

  @spec restore_health(player) :: {:ok, player} | {:error, atom}
  def restore_health(%Player{health: health}) when health == 0, do: {:error, :dead_player}
  def restore_health(%Player{cash: cash} = player) do
    case cash < Station.get_clinic_price() do
      true -> {:error, :insufficient_cash}
      false -> {:ok, %Player{player | cash: cash - Station.get_clinic_price(), health: @full_health}}
    end
  end


  # Packs ----------------------------------------------------------------------

  @doc """
  Returns an updated Player struct with increased pack size and reduced cash.

  Returns an error tuple if either the pack cost is greater than player cash, or
  the new pack size is not greater than the current pack size.

  ## Examples

      iex > FutureButcherEngine.Player.buy_pack(%Player{cash: 5000, pack_space: 20, ...}, 30, 1000)
      {:ok, FutureButcherEngine.Player%{cash: 4000, pack_space: 30, ...}}

      iex > FutureButcherEngine.Player.buy_pack(%Player{cash: 1000, ...}, 30, 2000)
      {:error, :insufficient_cash}

      iex > FutureButcherEngine.Player.buy_pack(%Player{pack_space: 30, ...}, 20, 1000)
      {:error, :must_upgrade_pack}
  """
  @spec buy_pack(player, cash :: integer, cost :: integer) :: {:ok, player} | {:error, atom}
  def buy_pack(%Player{cash: cash}, _, cost) when cash < cost, do: {:error, :insufficient_cash}

  def buy_pack(%Player{pack_space: current_space}, new_space, _cost)
  when current_space >= new_space, do: {:error, :must_upgrade_pack}

  def buy_pack(player, pack_space, cost) do
    adjust_cash(Map.put(player, :pack_space, pack_space), :decrease, cost)
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
    accrued_debt = debt * :math.pow((1 + @loan_rate), turns) |> round()
    {:ok, %Player{player | debt: accrued_debt}}
  end

  def accrue_debt(player, _turns), do: {:ok, player}

  @doc """
  Returns an updated Player struct with zeroed-out debt and decreased cash.

  Returns an error tuple if the debt amount to repay is greater than player cash.

  ## Examples

      iex > FutureButcherEngine.Player.pay_debt(%Player{debt: 5000, cash: 7000 ...})
      {:ok, %FutureButcherEngine.Player{debt: 0, cash: 2000, ...}}
  """
  @spec pay_debt(player) :: {:ok, player} | {:error, atom}
  def pay_debt(%Player{cash: f, debt: d}) when d > f, do: {:error, :insufficient_cash}

  def pay_debt(player) do
    {:ok, paid_player} = adjust_cash(player, :decrease, player.debt)
    {:ok, %Player{paid_player | debt: 0}}
  end


  # Buy/Sell Cuts --------------------------------------------------------------

  @doc """
  Returns an updated Player struct with reduced cash and an increased cut in the pack map.

  Returns an error tuple if the buy cost is greater than player cash.

  ## Examples

      iex > FutureButcherEngine.Player.buy_cut(%Player{cash: 5000, pack: %{}, ...}, :heart, 5, 1000)
      {:ok, %FutureButcherEngine.Player{cash: 4000, pack: %{heart: 5}, ...}}
  """
  @spec buy_cut(player, cut :: atom, amount :: integer, cost :: integer) :: {:ok, player} | {:error, atom}
  def buy_cut(%Player{cash: cash}, _cut, _amount, cost) when cash < cost do
    {:error, :insufficient_cash}
  end

  def buy_cut(player, cut, amount, cost) do
    with {:ok} <- sufficient_space?(player, amount) do
      {:ok, player} = adjust_cash(player, :decrease, cost)
      {:ok, player |> Map.put(:pack, increase_cut(player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  @doc """
  Returns an updated Player struct with increased cash and a reduced cut in the pack map.

  Returns an error tuple if the sell amount is greater than the cut owned.

  ## Examples

      iex > FutureButcherEngine.Player.sell_cut(%Player{cash: 5000, pack: %{heart: 5}, ...}, :heart, 3, 1000)
      {:ok, %FutureButcherEngine.Player{cash: 5000, pack: %{heart: 2}, ...}}
  """
  @spec sell_cut(player, cut :: atom, amount :: integer, profit :: integer) :: {:ok, player} | {:error, atom}
  def sell_cut(player, cut, amount, profit) do
    with {:ok} <- sufficient_cuts?(player.pack, cut, amount) do
      {:ok, player} = adjust_cash(player, :increase, profit)
      {:ok, player |> Map.put(:pack, decrease_cut(player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end


  # Weapons --------------------------------------------------------------------

  @doc """
  Returns an updated Player struct with a new weapon and adjusted cash.

  Returns an error tuple if weapon cost is greater than player cash, or player already owns weapon.

  ## Examples

      iex > FutureButcherEngine.Player.buy_weapon(%Player{cash: 5000, weapon: nil, ...}, :axe, 1000)
      {:ok, %FutureButcherEngine.Player{cash: 4000, weapon: :axe, ...}}

      iex > FutureButcherEngine.Player.buy_weapon(%Player{cash: 5000, weapon: :knife, ...}, :axe, 1000)
      {:error, :already_owns_weapon}

      iex > FutureButcherEngine.Player.buy_weapon(%Player{cash: 1000, weapon: nil, ...}, :axe, 2000)
      {:error, :insufficient_cash}
  """
  @spec buy_weapon(player, weapon :: atom, cost :: integer) :: {:ok, player} | {:error, atom}
  def buy_weapon(%Player{weapon: weapon}, _weapon, _cost) when not is_nil(weapon) do
    {:error, :already_owns_weapon}
  end

  def buy_weapon(%Player{cash: cash}, _weapon, cost) when cash < cost do
    {:error, :insufficient_cash}
  end

  def buy_weapon(player, weapon, cost) when weapon in @weapon_type do
    {:ok, player} = adjust_cash(player, :decrease, cost)
    {:ok, player |> Map.put(:weapon, weapon)}
  end

  def buy_weapon(_player, _weapon, _cost), do: {:error, :invalid_weapon_type}


  @doc """
  Returns an updated Player struct with a different weapon and adjusted cash.
  """
  @spec replace_weapon(player, weapon :: atom, cost :: integer, value :: integer) :: {:ok, player} | {:error, atom}
  def replace_weapon(%Player{weapon: weapon}, _weapon, _cost, _value) when is_nil(weapon) do
    {:error, :no_weapon_owned}
  end

  def replace_weapon(%Player{cash: cash}, _weapon, cost, value)
  when Kernel.+(cash, value) < cost, do: {:error, :insufficient_cash}

  def replace_weapon(%Player{weapon: current_weapon}, weapon, _cost, _value)
  when current_weapon == weapon, do: {:error, :same_weapon_type}

  def replace_weapon(player, weapon, cost, value) do
    {:ok, player} = adjust_cash(player, :increase, value)
    {:ok, player} = adjust_cash(player, :decrease, cost)
    {:ok, player |> Map.replace!(:weapon, weapon)}
  end

  @doc """
  Returns an updated Player struct with no weapon, or returns an error tuple if no weapon is owned.
  """
  @spec drop_weapon(player) :: {:ok, player} | {:error, atom}
  def drop_weapon(%Player{weapon: nil}), do: {:error, :no_weapon_owned}
  def drop_weapon(player), do: {:ok, player |> Map.replace!(:weapon, nil)}

  # Adrenal Gland Essential Oil ------------------------------------------------

  @doc """
  Returns an updated Player struct with has_oil set to true. If the player can't
  afford the oil, or is already holding oil, will return an erro.

    ## Examples

      iex > FutureButcherEngine.Player.buy_oil(%Player{has_oil: true, ...})
      {:error, :already_has_oil}

      iex > FutureButcherEngine.Player.buy_oil(%Player{cash: 19_999, ...})
      {:error, :insufficient_cash}

      iex > FutureButcherEngine.Player.buy_oil(%Player{cash: 30_000, has_oil: false, ...})
      {:ok, %Player{cash: 10_000, has_oil: true, ...}}
  """
  @spec buy_oil(player) :: {:ok, player} | {:error, atom}
  def buy_oil(%Player{has_oil: has_oil})
    when has_oil === true, do: {:error, :already_has_oil}
  def buy_oil(%Player{cash: cash} = player) do
    case cash >= Station.get_oil_price() do
      true ->
        {
          :ok, %Player{player |
            cash: cash - Station.get_oil_price(),
            has_oil: true
          }
        }
      false -> {:error, :insufficient_cash}
    end
  end


  @doc """
  Returns an updated Player struct with has_oil set to false. If the player has
  no oil, it is a no-op.

    ## Examples

      iex > FutureButcherEngine.Player.use_oil(%Player{has_oil: false, ...})
      {:ok, %Player{has_oil: false, ...}}

      iex > FutureButcherEngine.Player.use_oil(%Player{has_oil: true, ...})
      {:ok, %Player{has_oil: false, ...}}
  """
  @spec use_oil(player):: {:ok, player}
  def use_oil(player), do: {:ok, %Player{player | has_oil: false}}


  # Muggings -------------------------------------------------------------------

  @doc """
  Returns an updated Player struct adjusted on the outcome of the fight. When
  the player has no weapon, they have a 50% chance of successfully running. Each
  weapon increases the chance of winning the fight. If the player has essential
  oil, their chance of successfully running is 100%. If the player's health drops
  to 0 or below, will return a game-ending outcome.

    ## Examples

        iex > FutureButcherEngine.Player.fight_mugger(%Player{weapon: nil, ...})
        {:ok, %FutureButcherEngine.Player{...}, :defeat}

        iex > FutureButcherEngine.Player.fight_mugger(%Player{weapon: nil, has_oil: true ...})
        {:ok, %FutureButcherEngine.Player{...}, :victory}

        iex > FutureButcherEngine.Player.fight_mugger(%Player{pack: %{heart: 1, ...}, weapon: :machete, ...})
        {:ok, %FutureButcherEngine.Player{pack: %{heart: 2}}, :victory}

        iex > FutureButcherEngine.Player.fight_mugger(%Player{health: 20})
        {:ok, %FutureButcherEngine.Player{health: -10}, :death}
  """
  @spec fight_mugger(player) :: {:ok, player, outcome :: atom}
  def fight_mugger(%Player{weapon: nil, has_oil: true} = player) do
    {:ok, %Player{player | has_oil: false}, :victory}
  end

  def fight_mugger(%Player{weapon: nil} = player) do
    if get_run_outcome() > 5 do
      {:ok, player, :victory}
    else
      {:ok, damaged_player} = Player.decrease_health(player, get_damage())
      if (damaged_player.health > 0) do
        {:ok, damaged_player, :defeat}
      else
        {:ok, damaged_player, :death}
      end
    end
  end

  def fight_mugger(player) do
    {:ok, damaged_player} = Player.decrease_health(player, get_damage())
    if damaged_player.health <= 0 do
      {:ok, damaged_player, :death}
    else
      case Weapon.get_damage(damaged_player.weapon) >= Enum.random(1..10) do
        true ->
          {
            :ok,
            Map.replace(damaged_player, :pack, harvest_mugger(damaged_player)),
            :victory
          }
        false ->
          {:ok, damaged_player, :defeat}
      end
    end
  end

  @doc """
  Returns an adjusted Player struct with either cash reduced by 10% to 30% if player cash exceed $500, or
  an owned cut zeroed out.

  Returns an error tuple if player cash are under $500 and no cuts are owned.
  """
  @spec bribe_mugger(player) :: {:ok, player} | {:error, atom}
  def bribe_mugger(%Player{cash: cash} = player) when cash >= 500 do
    loss = Enum.random(10..30) |> Kernel./(100) |> (fn n -> round(cash * n) end).()
    adjust_cash(player, :decrease, loss)
  end

  def bribe_mugger(%Player{pack: pack} = player) do
    case get_random_cut(pack) do
      {:ok, cut, amount} -> {:ok, player |> Map.put(:pack, decrease_cut(pack, cut, amount))}
                  :error -> {:error, :cannot_bribe_mugger}
    end
  end


  # cash ----------------------------------------------------------------------

  @doc """
  Returns an adjusted Player struct with cash increased or decreased by the passed in amount.

    ## Examples

        iex > FutureButcherEngine.Player.adjust_cash(%Player{cash: 5000, ...}, :increase, 1000)
        %FutureButcherEngine.Player{cash: 6000, ...}

        iex > FutureButcherEngine.Player.adjust_cash(%Player{cash: 5000, ...}, :decrease, 1000)
        %FutureButcherEngine.Player{cash: 4000, ...}
  """
  @spec adjust_cash(player, direction :: atom, amount :: integer) :: {:ok, player}
  def adjust_cash(%Player{cash: cash} = player, :decrease, amount) when amount > cash do
    {:ok, player |> Map.put(:cash, 0)}
  end

  def adjust_cash(player, :decrease, amount) do
    {:ok, player |> decrease_attribute(:cash, amount) }
  end

  def adjust_cash(player, :increase, amount) do
    {:ok, player |> increase_attribute(:cash, amount)}
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

  def harvest_mugger(%{pack: pack, weapon: weapon}) when is_nil((weapon)) do
    pack
  end

  def harvest_mugger(%{pack: pack, weapon: weapon})
  when weapon in [:hockey_stick, :brass_knuckles], do: pack

  def harvest_mugger(%{pack: pack, pack_space: pack_space}) do
    weight_carried = Enum.reduce(pack, 0, fn {_, n}, acc -> acc + n end)
    space_available = pack_space - weight_carried
    harvest = %{brains: 1, heart: 1, flank: 2, liver: 1, ribs: 5}

    {new_pack, _} =
      Enum.reduce_while(pack, {pack, space_available}, fn {cut, carried}, acc ->
        to_add = Map.get(harvest, cut)
        update_pack(cut, carried, to_add, acc)
      end
    )

    new_pack
  end

  defp update_pack(_cut, _carried, _value, {pack, space}) when space === 0 do
    {:halt, {pack, space}}
  end

  defp update_pack(cut, carried, value, {pack, space})
    when value + carried >= space do
      {
        :halt,
        {Map.replace(pack, cut, carried + space), 0}
      }
  end

  defp update_pack(cut, carried, value, {pack, space}) do
    {
      :cont,
      {Map.replace(pack, cut, carried + value), space - value}
    }
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


  # Computations ===============================================================
  defp get_run_outcome(), do: Enum.random(0..9)

  defp get_damage(), do: Enum.random(20..60)
end
