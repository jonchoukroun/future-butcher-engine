defmodule FutureButcherEngine.Game do
  alias __MODULE__

  @enforce_keys [:turns_left]
  defstruct [:turns_left]

  def new(turns) do
    {:ok, %Game{turns_left: turns}}
  end

  def end_turn(game, %{turns_left: turns_left}) when turns_left > 0 do
    {:ok, game
          |> decrement_turn()}
  end

  def end_turn(game, %{turns_left: turns_left}) do
    {:ok, :game_over}
  end

  defp decrement_turn(game) do
    game
    |> Map.put(:turns_left, Map.get(game, :turns_left) - 1)
  end

end