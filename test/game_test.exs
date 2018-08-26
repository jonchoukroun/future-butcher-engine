defmodule GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.{Game, GameSupervisor, Rules, Player}


  # Game init ------------------------------------------------------------------

  describe ".init" do
    setup _context do
      {:ok, state} = Game.init "Frank"
      %{state: state}
    end

    test "creates player with no finances or weapon", context do
      assert context.state.player.player_name == "Frank"
      assert context.state.player.funds       == 0
      assert context.state.player.debt        == 0
      assert context.state.player.rate        == 0
      assert context.state.player.weapon      == nil
    end

    test "sets turns and game state", context do
      assert context.state.rules.turns_left == 25
      assert context.state.rules.state      == :initialized
    end

    test "does not set station", context do
      assert context.state.station == nil
    end
  end

  describe ".start_game" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      {:ok, state} = Game.start_game(game)

      on_exit fn -> GameSupervisor.stop_game "Frank" end

      %{state: state}
    end

    test "Decrements turns", context do
      assert context.state.rules.turns_left == 24
    end

    test "Sets station to downtown", context do
      assert context.state.station.station_name == :downtown
      assert context.state.station.market       != nil
    end

    test "Player does not yet have capital", context do
      assert context.state.player.funds == 0
      assert context.state.player.debt  == 0
      assert context.state.player.rate  == 0
    end
  end


  # Debt/loans -----------------------------------------------------------------


  # Buy/sell cuts --------------------------------------------------------------


  # Travel/transit -------------------------------------------------------------

  describe ".change_station when in game" do
    setup _context do
      {:ok, game}       = GameSupervisor.start_game("Frank")
      {:ok, base_state} = Game.start_game(game)
      {:ok, test_state} = Game.change_station(game, :compton)

      on_exit fn -> GameSupervisor.stop_game "Frank" end

      %{base_state: base_state, test_state: test_state}
    end

    test "changes game state", context do
      random_occurence_outcomes = [:mugging, :in_game]
      assert Enum.member?(random_occurence_outcomes, context.test_state.rules.state)
    end

    test "station is updated", context do
      assert context.test_state.station.station_name == :compton
    end

    test "decrements turn by 1", context do
      assert context.base_state.rules.turns_left - context.test_state.rules.turns_left == 1
    end
  end

  describe ".fight_mugger" do
    setup _context do
      {:ok, game}  = GameSupervisor.start_game("Frank")
      {:ok, state} = Game.start_game(game)

      test_rules = %Rules{turns_left: 10, state: :mugging}
      :sys.replace_state game, fn _state -> %{state | rules: test_rules} end

      on_exit fn -> GameSupervisor.stop_game "Frank" end

      %{game: game}
    end

    test "with no weapon decrements turns", context do
      base_state        = :sys.get_state context.game
      {:ok, test_state} = Game.fight_mugger(context.game)

      assert base_state.rules.turns_left > test_state.rules.turns_left
    end

    test "restores in_game state", context do
      base_state  = :sys.get_state context.game
      test_player = %Player{base_state.player | weapon: :machete}
      :sys.replace_state context.game, fn _state -> %{base_state | player: test_player} end

      {:ok, test_state} = Game.fight_mugger(context.game)

      assert test_state.rules.state === :in_game
    end

    test "with 0 turns left", context do
      base_state = :sys.get_state context.game
      test_rules = %Rules{base_state.rules | turns_left: 0}
      :sys.replace_state context.game, fn _state -> %{base_state | rules: test_rules} end

      assert Game.fight_mugger(context.game) === :violates_current_rules
    end
  end

  describe ".pay_mugger :funds" do
    setup _context do
      {:ok, game}  = GameSupervisor.start_game("Frank")
      {:ok, state} = Game.start_game(game)

      test_rules = %Rules{state.rules | state: :mugging}
      :sys.replace_state game, fn _state -> %{state | rules: test_rules} end

      on_exit fn -> GameSupervisor.stop_game("Frank") end

      %{game: game}
    end

    test "with 0 funds returns error", context do
      assert Game.pay_mugger(context.game, :funds) === :insufficient_funds
    end

    test "with funds decreases funds and restores in game state", context do
      base_state  = :sys.get_state context.game
      test_player = %Player{base_state.player | funds: 1000}
      :sys.replace_state context.game, fn _state -> %{base_state | player: test_player} end

      starting_state = :sys.get_state context.game

      {:ok, test_state} = Game.pay_mugger(context.game, :funds)

      assert starting_state.player.funds > test_state.player.funds
      assert test_state.rules.state === :in_game
    end
  end


  # Weapons --------------------------------------------------------------------


end
