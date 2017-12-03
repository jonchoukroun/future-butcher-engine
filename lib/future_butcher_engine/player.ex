defmodule FutureButcherEngine.Player do
  alias __MODULE__

  @enforce_keys [:player_name, :health, :funds, :debt, :pack]
  defstruct [:player_name, :health, :funds, :debt, :pack]

  @max_health 100
  @cut_keys [:flank, :heart, :loin, :liver, :ribs]

  def new(health, funds) when health <= @max_health and funds > 0 do
    {:ok, %Player{
      player_name: nil, health: health, funds: funds, debt: funds,
      pack: initialize_pack()
     }}
  end

  def new(_health, _funds) do
    {:error, :invalid_player_values}
  end

  def adjust_pack(%{pack: pack} = player, cut, amount, :buy) do
    # below needs to be fixed to find matching cut as passed in and return map
    Enum.find(pack, fn el -> Map.get(el, cut) = cut end)
    {:ok, :something}
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

  defp initialize_pack do
    Enum.map(@cut_keys, fn cut -> %{cut => nil} end)
  end

  defp increase_attribute(player, amount, attribute) do
    player |> Map.put(attribute, Map.get(player, attribute) + amount)
  end

  defp decrease_attribute(player, amount, attribute) do
    player |> Map.put(attribute, Map.get(player, attribute) - amount)
  end

end