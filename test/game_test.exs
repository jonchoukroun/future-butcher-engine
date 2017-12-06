defmodule FutureButcherEngine.GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.Game

  @turns 30

  test "Game.new/1 with valid turns arg creates game struct" do
    assert Game.new(@turns) == {:ok, %Game{turns_left: 29}}
  end

  test "Game.new/1 with turn over max returns error" do
    assert Game.new(@turns + 1) == {:error, :exceeds_max_turns}
  end

  test "Game.new/1 with invalid turns arg returns error" do
    assert Game.new('turn') == {:error, :invalid_turns_number}
  end

  test "Game.end_turn/1 with no turns left returns game over" do
    {:ok, game} = Game.new(1)
    assert Game.end_turn(game) == {:ok, :game_over}
  end

  test "Game.end_turn/1 with turns left succeeds and returns struct" do
    {:ok, game} = Game.new(@turns)
    assert Game.end_turn(game) == {:ok, %Game{turns_left: 28}}
  end

end