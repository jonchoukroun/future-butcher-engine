defmodule FutureButcherEngine.Player do
  alias __MODULE__

  @enforce_keys [:player_name, :health, :funds, :debt]
  defstruct [
    :player_name, :health, :funds, :debt, :flank, :heart, :loin, :liver, :ribs
  ]

  @max_health 100

  def new(health, funds) when health <= @max_health and funds > 0 do
    {:ok, %Player{
     health: health, funds: funds, debt: funds,
     flank: nil, heart: nil, loin: nil, liver: nil, ribs: nil,
     player_name: nil
     }}
  end

  def new(_health, _funds) do
    {:error, :invalid_player_values}
  end

  def adjust_funds(%Player{funds: funds} = player, amount, :buy) when
    amount > funds do
    {:error, :insufficient_funds}
  end

  def adjust_funds(%{funds: funds} = player, amount, :buy) do
    {:ok, player |> decrease_attribute(amount, :funds) }
  end

  def adjust_funds(%{funds: funds} = player, amount, :sell) do
    {:ok , player |> increase_attribute(amount, :funds)}
  end

  def adjust_health(%Player{health: health} = player, amount, :heal) when
    amount + health > @max_health do
    {:ok, player |> increase_attribute((@max_health - health), :health)}
  end

  def adjust_health(%Player{health: health} = player, amount, :heal) do
    {:ok, player |> increase_attribute(amount, :health)}
  end

  def adjust_health(%Player{health: health}, amount, :hurt) when
    amount > health do
      {:ok, :player_dead}
  end

  def adjust_health(%Player{health: health} = player, amount, :hurt) do
    {:ok, player |> decrease_attribute(amount, :health)}
  end

  defp increase_attribute(player, amount, attribute) do
    player |> Map.put(attribute, Map.get(player, attribute) + amount)
  end

  defp decrease_attribute(player, amount, attribute) do
    player |> Map.put(attribute, Map.get(player, attribute) - amount)
  end

end