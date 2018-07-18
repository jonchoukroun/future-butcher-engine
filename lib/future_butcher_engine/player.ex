defmodule FutureButcherEngine.Player do
  alias __MODULE__

  @enforce_keys [:player_name, :health, :funds, :principle, :interest, :pack]
  defstruct [:player_name, :health, :funds, :principle, :interest, :pack]

  @max_health 100
  @max_space 20
  @cut_keys [:flank, :heart, :loin, :liver, :ribs]

  def new(player_name) when is_binary(player_name) do
    %Player{
      player_name: player_name,
      health: @max_health,
      funds: 0, principle: 0, interest: 0.0,
      pack: initialize_pack()}
  end

  def new(_name) do
    {:error, :invalid_player_name}
  end

  def buy_loan(player, principle, interest) when is_integer(interest) do
    buy_loan(player, principle, interest * 1.0)
  end

  def buy_loan(player, principle, interest) when is_integer(principle) and is_float(interest) do
    player = increase_attribute(player, :principle, principle)
    player = increase_attribute(player, :interest, interest)
    {:ok, player} = adjust_funds(player, :increase, principle)
  end

  def buy_loan(_) do
    {:error, :invalid_loan_values}
  end

  def buy_cut(player, cut, amount, cost) do
    with {:ok} <- sufficient_funds?(player, cost),
         {:ok} <- sufficient_space?(player, amount)
     do
      {:ok, player} = adjust_funds(player, :decrease, cost)
      {:ok, player
            |> Map.replace(:pack, increase_cut(player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def sell_cut(player, cut, amount, profit) do
    with {:ok} <- sufficient_cuts?(player.pack, cut, amount)
    do
      {:ok, player} = adjust_funds(player, :increase, profit)
      {:ok, player
            |> Map.replace(:pack, decrease_cut(player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def accrue_debt(%Player{principle: principle, interest: interest} = player) when principle > 0 do
    new_principle =
      principle |> Kernel.*(1000) |> Kernel.*(interest) |> Kernel./(1000) |> Kernel.round
    {:ok, player |> increase_attribute(:principle, new_principle)}
  end

  def accrue_debt(player), do: {:ok, player}

  def pay_debt(%Player{funds: funds, principle: principle} = player, amount)
  when funds > amount and amount >= principle do
    {:ok, player} = adjust_funds(player, :decrease, principle)
    {:ok, player
          |> decrease_attribute(:principle, principle)
          |> decrease_attribute(:interest, player.interest)}
  end

  def pay_debt(%Player{funds: funds, principle: principle} = player, amount) when funds > amount do
    payoff = Enum.min [principle, amount]
    {:ok, player} = adjust_funds(player, :decrease, payoff)
    {:ok, player |> decrease_attribute(:principle, payoff)}
  end

  def pay_debt(_player, _amount), do: {:error, :insufficient_funds}

  def adjust_funds(%Player{funds: funds} = player, :decrease, amount)
  when amount > funds do
    {:ok, player |> Map.put(:funds, 0)}
  end

  def adjust_funds(player, :decrease, amount) do
    {:ok, player |> decrease_attribute(:funds, amount) }
  end

  def adjust_funds(player, :increase, amount) do
    {:ok, player |> increase_attribute(:funds, amount)}
  end

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

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end

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
