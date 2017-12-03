defmodule FutureButcherEngine.Player do
  alias __MODULE__

  @enforce_keys [:player_name, :health, :funds, :debt]
  defstruct [:player_name, :health, :funds, :debt]

  @health_range 1..100

  def new(health, funds) when health in (@health_range) and funds > 0 do
    {:ok, %Player{player_name: nil, health: health, funds: funds, debt: funds}}
  end

  def new(_health, _funds) do
    {:error, :invalid_player_values}
  end

  def adjust_health(%Player{health: health}, amount, :hurt) when
    amount > health do
      {:ok, :player_dead}
  end

  def adjust_health(%Player{health: health} = player, amount, :hurt) do
    {:ok, player |> decrease_health(amount)}
  end

  def adjust_health(%Player{health: health} = player, amount, :heal) when
    amount + health > 100 do
    {:ok, player |> increase_health(100 - health)}
  end

  def adjust_health(%Player{health: health} = player, amount, :heal) do
    {:ok, player |> increase_health(amount)}
  end

  def adjust_funds(%Player{funds: funds} = player, amount, :buy) when
    amount > funds do
    {:error, :insufficient_funds}
  end

  def adjust_funds(%{funds: funds} = player, amount, :buy) do
    {:ok, player |> decrease_funds(amount) }
  end

  def adjust_funds(%{funds: funds} = player, amount, :sell) do
    {:ok , player |> increase_funds(amount)}
  end

  defp decrease_health(player, amount) do
    player |> Map.put(:health, Map.get(player, :health) - amount)
  end

  defp increase_health(player, amount) do
    player |> Map.put(:health, Map.get(player, :health) + amount)
  end

  defp decrease_funds(player, amount) do
    player |> Map.put(:funds, Map.get(player, :funds) - amount)
  end

  defp increase_funds(player, amount) do
    player |> Map.put(:funds, Map.get(player, :funds) + amount)
  end

end