defmodule FutureButcherEngine.Player do
  alias FutureButcherEngine.{Player, Cut}

  @enforce_keys [:player_name, :health, :funds, :debt, :rate, :pack]
  defstruct [:player_name, :health, :funds, :debt, :rate, :pack]

  @max_health 100
  @max_space 20
  @cut_keys [:flank, :heart, :loin, :liver, :ribs]

  def new(player_name) when is_binary(player_name) do
    %Player{
      player_name: player_name,
      health: @max_health,
      funds: 0, debt: 0, rate: 0.0,
      pack: initialize_pack()}
  end

  def new(_name) do
    {:error, :invalid_player_name}
  end

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

  def buy_cut(player, cut, amount, cost) do
    with {:ok} <- sufficient_funds?(player, cost),
         {:ok} <- sufficient_space?(player, amount)
     do
<<<<<<< HEAD
      {:ok, player} = adjust_funds(player, cost, :decrease)
      {:ok, player |> Map.put(:pack, increase_cut(player.pack, cut, amount))}
=======
      {:ok, player} = adjust_funds(player, :decrease, cost)
      {:ok, player
            |> Map.put(:pack, increase_cut(player.pack, cut, amount))}
>>>>>>> master
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def sell_cut(player, cut, amount, profit) do
    with {:ok} <- sufficient_cuts?(player.pack, cut, amount)
    do
<<<<<<< HEAD
      {:ok, player} = adjust_funds(player, profit, :increase)
      {:ok, player |> Map.put(:pack, decrease_cut(player.pack, cut, amount))}
=======
      {:ok, player} = adjust_funds(player, :increase, profit)
      {:ok, player
            |> Map.put(:pack, decrease_cut(player.pack, cut, amount))}
>>>>>>> master
    else
      {:error, msg} -> {:error, msg}
    end
  end

<<<<<<< HEAD
=======
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

>>>>>>> master
  def pay_debt(%Player{funds: funds, debt: debt} = player, amount) when funds > amount do
    payoff = Enum.min [debt, amount]
    {:ok, player} = adjust_funds(player, :decrease, payoff)
    {:ok, player |> decrease_attribute(:debt, payoff)}
  end

  def pay_debt(_player, _amount), do: {:error, :insufficient_funds}

<<<<<<< HEAD
  def handle_travel(player) do
    {:ok, player} = accrue_debt(player)
    {:ok, player} = determine_random_encounter(player) |> handle_encounter(player)
  end

  def handle_encounter(:mugging, player), do: {:ok, player}

  def handle_encounter(:find_pack, %{amount: amount}, player) when amount == 0, do: {:ok, player}

  def handle_encounter(:find_pack, %{cut: cut, amount: amount}, player) do
    case sufficient_space?(player, amount) do
      {:ok} ->
        {:ok, player |> Map.put(:pack, increase_cut(player.pack, cut, amount))}

      {:error, :insufficient_pack_space} ->
        handle_encounter(:find_pack, %{cut: cut, amount: amount - 1}, player)
    end
  end

  def handle_encounter(:no_encounter, player), do: {:ok, player}

  # Player adjustments

  def accrue_debt(%Player{debt: debt} = player) when debt > 0 do
    new_debt = debt
      |> Kernel.*(1000)
      |> Kernel.*(0.15)
      |> Kernel./(1000)
      |> Kernel.round

    {:ok, player |> increase_attribute(new_debt, :debt)}
  end

  def accrue_debt(player), do: {:ok, player}

  def adjust_funds(%Player{funds: funds} = player, amount, :decrease) when amount > funds do
=======
  def adjust_funds(%Player{funds: funds} = player, :decrease, amount)
  when amount > funds do
>>>>>>> master
    {:ok, player |> Map.put(:funds, 0)}
  end

  def adjust_funds(player, :decrease, amount) do
    {:ok, player |> decrease_attribute(:funds, amount) }
  end

  def adjust_funds(player, :increase, amount) do
    {:ok, player |> increase_attribute(:funds, amount)}
  end

<<<<<<< HEAD
  def adjust_health(%Player{health: health} = player, amount, :heal)
  when amount + health > @max_health do
    {:ok, player |> increase_attribute((@max_health - health), :health)}
  end

  def adjust_health(player, amount, :heal) do
    {:ok, player |> increase_attribute(amount, :health)}
  end

  def adjust_health(%Player{health: health}, amount, :hurt) when amount > health do
      {:ok, :player_dead}
  end

  def adjust_health(player, amount, :hurt) do
    {:ok, player |> decrease_attribute(amount, :health)}
  end
=======
  # def adjust_health(%Player{health: health} = player, :heal, amount)
  # when amount + health > @max_health do
  #   {:ok, player |> increase_attribute(:health, (@max_health - health))}
  # end
  #
  # def adjust_health(player, :heal, amount) do
  #   {:ok, player |> increase_attribute(:health, amount)}
  # end
  #
  # def adjust_health(%Player{health: health}, :hurt, amount)
  # when amount > health do
  #     {:ok, :player_dead}
  # end
  #
  # def adjust_health(player, :hurt, amount) do
  #   {:ok, player |> decrease_attribute(:health, amount)}
  # end
>>>>>>> master


  # Value modifiers

  def increase_cut(pack, cut, amount) do
    pack |> Map.put(cut, Map.get(pack, cut) + amount)
  end

  defp decrease_cut(pack, cut, amount) do
    pack |> Map.put(cut, Map.get(pack, cut) - amount)
  end

  defp increase_attribute(player, amount, attribute) do
    player |> Map.put(attribute, Map.get(player, attribute) + amount)
  end

  defp decrease_attribute(player, amount, attribute) do
    player |> Map.put(attribute, Map.get(player, attribute) - amount)
  end


  # Validations

  defp sufficient_funds?(player, cost) do
    if (player.funds >= cost), do: {:ok}, else: {:error, :insufficient_funds}
  end

  defp sufficient_space?(player, amount) do
    space_taken = player.pack
    |> Map.values
    |> Enum.reduce(0, fn(x, acc) -> x + acc end)

    if space_taken + amount <= @max_space do
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

  # Misc

  defp pick_random_cut do
    Enum.random(Cut.get_cuts_list)
  end

  defp calculate_cash_mugging(player) do
    Float.round(player.funds * 0.80)
  end

<<<<<<< HEAD
  defp determine_random_encounter(player) do
    case Enum.random(1..10) do
      n when n in 1..4  ->
        {:mugging, %{damage: Enum.random(10..20), cash: calculate_cash_mugging(player)}}
      n when n in 5..8  ->
        {:find_pack, %{cut: pick_random_cut(), amount: Enum.random(1..3)}}
      n when n in 9..10 ->
        :no_encounter
    end
  end

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end


=======
  defp increase_attribute(player, attribute, amount) do
    player |> Map.put(attribute, Map.get(player, attribute) + amount)
  end

  defp decrease_attribute(player, attribute, amount) do
    player |> Map.put(attribute, Map.get(player, attribute) - amount)
  end

>>>>>>> master
end
