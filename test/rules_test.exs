defmodule FutureButcherEngine.RulesTest do
  use ExUnit.Case
  alias FutureButcherEngine.Rules

  test "New rules struct created with living player and initialized state" do
    rules = Rules.new()
    assert rules.player == :alive
    assert rules.state  == :initialized
  end

  test "Any action on dead player ends game" do
    rules = Rules.new()
    rules = %Rules{rules | player: :dead}
    assert rules.player == :dead
    {:ok, rules} = Rules.check(rules, :visit_subway)
    assert rules.state == :game_end
  end

  test "Start game action only moves to in game state from initialized" do
    rules = Rules.new()
    assert Rules.check(rules, :visit_market) == :error
    {:ok, rules} = Rules.check(rules, :start_game)
    assert rules.state == :in_game
  end

end