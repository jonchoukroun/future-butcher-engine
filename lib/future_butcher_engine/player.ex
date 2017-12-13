defmodule FutureButcherEngine.Player do
  alias __MODULE__

  @enforce_keys [:player_name, :health, :funds, :debt, :pack]
  defstruct [:player_name, :health, :funds, :debt, :pack]

  @max_health 100
  @max_space 20
  @cut_keys [:flank, :heart, :loin, :liver, :ribs]

  def new(health, funds) when health <= @max_health and funds > 0 do
    %Player{
      player_name: nil, health: health, funds: funds, debt: funds,
      pack: initialize_pack()}
  end

  def new(_health, _funds) do
    {:error, :invalid_player_values}
  end

  def adjust_pack(%Player{pack: pack} = player, cut, amount, price, :buy) do
    with {:ok, cost} <- sufficient_funds?(player, amount, price),
         {:ok}       <- sufficient_space?(player, amount)
     do
      {:ok, player} = adjust_funds(player, (amount * price), :decrease)
      {:ok, player |> Map.replace(:pack, increase_cut(
        player.pack, cut, amount))}
    else
      {:error, msg} -> {:error, msg}
    end
  end

  def adjust_pack(%Player{pack: pack} = player, cut, amount, price, :sell) do
    {:ok, player} = adjust_funds(player, (amount * price), :increase)
    {:ok, player |> Map.replace(:pack, decrease_cut(player.pack, cut, amount))}
  end

  def repay_debt(%Player{funds: funds, debt: debt} = player)
  when funds >= debt do
    {:ok, player} = adjust_funds(player, debt, :decrease)
    {:ok, player |> decrease_attribute(debt, :debt)}
  end

  def repay_debt(%Player{}), do: {:error, :insufficient_funds}

  def adjust_funds(%Player{funds: funds} = player, amount, :decrease)
  when amount > funds do
    {:error, :insufficient_funds}
  end

  def adjust_funds(%Player{funds: funds} = player, amount, :decrease) do
    {:ok, player |> decrease_attribute(amount, :funds) }
  end

  def adjust_funds(%Player{funds: funds} = player, amount, :increase) do
    {:ok , player |> increase_attribute(amount, :funds)}
  end

  def adjust_health(%Player{health: health} = player, amount, :heal)
  when amount + health > @max_health do
    {:ok, player |> increase_attribute((@max_health - health), :health)}
  end

  def adjust_health(%Player{health: health} = player, amount, :heal) do
    {:ok, player |> increase_attribute(amount, :health)}
  end

  def adjust_health(%Player{health: health}, amount, :hurt)
  when amount > health do
      {:ok, :player_dead}
  end

  def adjust_health(%Player{health: health} = player, amount, :hurt) do
    {:ok, player |> decrease_attribute(amount, :health)}
  end

  defp initialize_pack do
    Map.new(@cut_keys, fn cut -> {cut, 0} end)
  end

  defp sufficient_funds?(player, amount, price) do
    if player.funds >= (amount * price) do
      {:ok, (amount * price)}
    else
      {:error, :insufficient_funds}
    end
  end

  defp sufficient_space?(player, amount) do
    space_taken = player.pack
    |> Map.values
    |> Enum.reduce(0, fn(x, acc) -> x + acc end)

    if space_taken + amount < @max_space do
      {:ok}
    else
      {:error, :insufficient_pack_space}
    end
  end

  defp increase_cut(pack, cut, amount) do
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

end