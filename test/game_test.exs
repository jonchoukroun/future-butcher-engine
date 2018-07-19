defmodule GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.Game

  test "Initializing game creates named player with health and no finances" do
    {:ok, state} = Game.init("Frank")
    assert state.player.player_name == "Frank"
    assert state.player.health      == 100
    assert state.player.funds       == 0
    assert state.player.debt        == 0
    assert state.player.rate        == 0.0
  end

  test "Initializing game sets turns and game state" do
    {:ok, state} = Game.init("Frank")
    assert state.rules.turns_left == 25
    assert state.rules.state      == :initialized
  end

  test "Initializing game doesn't set station" do
    {:ok, state} = Game.init("Frank")
    assert state.station == nil
  end

end
