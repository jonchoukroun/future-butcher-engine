defmodule FutureButcherEngine.Game do
  alias __MODULE__

  @enforce_keys [:turns_left]
  defstruct [:turns_left]

  @max_turns 30

  def new(turns) when is_integer(turns) and turns <= @max_turns do
    {:ok, %Game{turns_left: turns - 1}}
  end

  def new(turns) when is_integer(turns) and turns > @max_turns do
    {:error, :exceeds_max_turns}
  end

  def new(_) do
    {:error, :invalid_turns_number}
  end

  def end_turn(%{turns_left: turns_left} = game) when turns_left > 0 do
    {:ok, game |> decrement_turn()}
  end

  def end_turn(%{turns_left: turns_left} = game) do
    {:ok, :game_over}
  end

  defp decrement_turn(game) do
    game |> Map.put(:turns_left, Map.get(game, :turns_left) - 1)
  end

end