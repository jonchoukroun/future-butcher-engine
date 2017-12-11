defmodule FutureButcherEngine.Game do
  alias __MODULE__

  @enforce_keys [:turns_left, :state]
  defstruct [:turns_left, :state]

  def new(turns) when is_integer(turns) do
    %Game{turns_left: turns, state: :initialized}
  end

  def new(_) do
    {:error, :invalid_turns}
  end

  def check(%Game{state: :game_over}, _action) do
    {:error, :game_over}
  end

  def check(%Game{state: :initialized} = game, :start_game) do
    game = decrement_turn(game)
    {:ok, %Game{game | state: :in_game}}
  end

  def check(%Game{state: :in_game} = game, :visit_market) do
    {:ok, %Game{game | state: :at_market}}
  end

  def check(%Game{state: :in_game} = game, :visit_subway) do
    {:ok, %Game{game | state: :at_subway}}
  end

  def check(%Game{state: :in_game} = game, :end_game) do
    {:ok, %Game{game | state: :game_over}}
  end

  def check(%Game{state: :at_market} = game, :buy_cut) do
    {:ok, %Game{game | state: :at_market}}
  end

  def check(%Game{state: :at_market} = game, :sell_cut) do
    {:ok, %Game{game | state: :at_market}}
  end

  def check(%Game{state: :at_market} = game, :leave_market) do
    {:ok, %Game{game | state: :in_game}}
  end

  def check(%Game{state: :at_subway} = game, :leave_subway) do
    {:ok, %Game{game | state: :in_game}}
  end

  def check(%Game{state: :at_subway, turns_left: 0} = game, :change_station) do
    {:ok, %Game{game | state: :game_over}}
  end

  def check(%Game{state: :at_subway} = game, :change_station) do
    game = decrement_turn(game)
    {:ok, %Game{game | state: :in_game}}
  end

  def check(_state, _action), do: :error

  defp decrement_turn(game) do
    game |> Map.put(:turns_left, Map.get(game, :turns_left) - 1)
  end

end