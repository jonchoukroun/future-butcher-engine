defmodule FutureButcherEngine.RulesTest do
  use ExUnit.Case
  use FutureButcherEngine.SharedExamples.FailedActions
  alias FutureButcherEngine.{Rules}
  import FutureButcherEngine.SharedExamples.FailedActions

  test "Passing non integer or less than 1 to new rules returns error" do

    assert Rules.new("10") == {:error, :invalid_turns}
    assert Rules.new(nil)  == {:error, :invalid_turns}
    assert Rules.new(0)    == {:error, :invalid_turns}
  end

  describe "Initialized game with valid number of turns" do
    setup do: {:ok, rules: %Rules{turns_left: 10, state: :initialized}}

    test "Start game decrements turns and updates state", context do
      {:ok, rules} = Rules.check(context.rules, :start_game)
      assert rules.state == :in_game
      assert rules.turns_left == 9
    end
  end

  describe "Game with no turns left" do
    setup do
      rules = %Rules{Rules.new(1) | turns_left: 0, state: :in_game}
      {:ok, rules: rules}
    end

    test "Changing station from subway ends game", context do
      {:ok, rules} = Rules.check(context.rules, :visit_subway)
      {status, rules} = Rules.check(rules, :change_station)
      assert status == :game_over
      assert rules.state == :game_over
    end
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
    assert Rules.check(rules, :bullshit_action) == {
      :error, :violates_current_rules}
    assert Rules.check(5, :visit_subway) == {:error, :violates_current_rules}
  end

end