defmodule FutureButcherEngine.GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.Game

  test "Passing non integer or less than 1 to new game returns error" do
    assert Game.new("10") == {:error, :invalid_turns}
    assert Game.new(nil)  == {:error, :invalid_turns}
    assert Game.new(0)    == {:error, :invalid_turns}
  end

  test "No events change game over state" do
    game = Game.new(4)
    game = %Game{game | state: :game_over}
    assert Game.check(game, :any_action) == {:error, :game_over}
  end

  test "Change station event returns in game state and decrements turns left" do
    game = Game.new(5)
    game = %Game{game | state: :at_subway}
    {:ok, game} = Game.check(game, :change_station)
    assert game.state == :in_game
    assert game.turns_left == 4
  end

  test "Failure to pass valid state or action returns generic error" do
    game = Game.new(1)
    assert Game.check(game, :bullshit_action) == :error
    assert Game.check(5, :visit_subway)       == :error
  end

end