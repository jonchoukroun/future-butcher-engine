defmodule FutureButcherEngine.RulesTest do
  use ExUnit.Case
  alias FutureButcherEngine.Rules

  test "Passing non integer or less than 1 to new rules returns error" do

    assert Rules.new("10") == {:error, :invalid_turns}
    assert Rules.new(nil)  == {:error, :invalid_turns}
    assert Rules.new(0)    == {:error, :invalid_turns}
  end

  describe "Initialized game with valid number of turns" do
    setup _context do
      {:ok, rules: %Rules{turns_left: 10, state: :initialized}}
    end

    test "Start game updates state", context do
      {:ok, rules} = Rules.check(context.rules, :start_game)
      assert rules.state == :in_game
    end
  end

  test "No events change rules over state" do
    rules = Rules.new(4)
    rules = %Rules{rules | state: :game_over}
    assert Rules.check(rules, :any_action) == {:error, :game_over}
  end

  test "Failure to pass valid state or action returns generic error" do
    rules = Rules.new(1)
    assert Rules.check(rules, :bullshit_action) == {
      :error, :violates_current_rules}
    assert Rules.check(5, :visit_subway) == {:error, :violates_current_rules}
  end

  describe "Changing station" do
    setup _context do
      {:ok, rules: %Rules{turns_left: 10, state: :in_game}}
    end

    test "with state mugging restricts actions", context do
      testing_rules = %Rules{context.rules | state: :mugging}

      [:change_station, :buy_cut, :sell_cut, :buy_weapon, :pay_debt]
      |> Enum.each(fn action ->
        assert Rules.check(testing_rules, action) === {:error, :violates_current_rules} end)
    end
  end

end
