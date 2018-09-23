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

  describe ".buy_loan" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)

      on_exit fn -> GameSupervisor.stop_game("Frank") end

      %{game: game}
    end

    test "should increase funds, debt, and set rate", context do
      Game.buy_loan(context.game, 5000, 0.2)
      test_data = :sys.get_state context.game

      assert test_data.player.funds === 5000
      assert test_data.player.debt === 5000
      assert test_data.player.rate === 0.2
    end

    test "should return error if buying loan outside downtown", context do
      # may error on offchance of mugging
      Game.change_station(context.game, :compton)
      assert Game.buy_loan(context.game, 5000, 0.2) === :must_be_downtown
    end
  end

  describe ".pay_loan" do
  end

  # Buy/sell cuts --------------------------------------------------------------


  # Travel/transit -------------------------------------------------------------

  describe ".change_station when in game" do
    setup _context do
      {:ok, game}       = GameSupervisor.start_game("Frank")
      Game.start_game(game)
      {:ok, base_state} = Game.buy_loan(game, 5000, 0.2)
      {:ok, test_state} = Game.change_station(game, :compton)

      on_exit fn -> GameSupervisor.stop_game "Frank" end

      %{base_state: base_state, test_state: test_state, game: game}
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

    test "with exisitng player debt rate accrues debt", context do
      assert context.test_state.player.rate === 0.2
      assert context.test_state.player.debt === 6000
    end

    test "to compton should charge no entry fee", context do
      assert context.base_state.player.funds === context.test_state.player.funds
    end

    test "to other stations should charge entry fee", context do
      {:ok, travel_state} = Game.change_station(context.game, :hollywood)
      assert context.base_state.player.funds > travel_state.player.funds
    end

    test "should return error when entry fee is too expensive", context do
      assert Game.change_station(context.game, :beverly_hills) === :insufficient_funds
    end

    test "with 0 turns left ends game", context do
      test_rules = %Rules{context.test_state.rules | turns_left: 0}
      :sys.replace_state context.game, fn _state -> %{context.test_state | rules: test_rules} end

      {end_response, end_state} = Game.change_station(context.game, :hollywood)

      assert end_response          === :game_over
      assert end_state.rules.state === :game_over
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
