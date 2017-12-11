defmodule FutureButcherEngine.RulesTest do
  use ExUnit.Case
  alias FutureButcherEngine.Rules

  test "Passing non integer or less than 1 to new rules returns error" do
    assert Rules.new("10") == {:error, :invalid_turns}
    assert Rules.new(nil)  == {:error, :invalid_turns}
    assert Rules.new(0)    == {:error, :invalid_turns}
  end

  test "No events change rules over state" do
    rules = Rules.new(4)
    rules = %Rules{rules | state: :game_over}
    assert Rules.check(rules, :any_action) == {:error, :game_over}
  end

  test "Change station returns in rules state and decrements turns left" do
    rules = Rules.new(5)
    rules = %Rules{rules | state: :at_subway}
    {:ok, rules} = Rules.check(rules, :change_station)
    assert rules.state == :in_game
    assert rules.turns_left == 4
  end

  test "Failure to pass valid state or action returns generic error" do
    rules = Rules.new(1)
    assert Rules.check(rules, :bullshit_action) == :error
    assert Rules.check(5, :visit_subway)       == :error
  end

end