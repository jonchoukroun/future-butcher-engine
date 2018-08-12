defmodule GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.{Game, GameSupervisor, Player}


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

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

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
      {:ok, game} = GameSupervisor.start_game("Frank")
      {:ok, starting_state} = Game.start_game(game)
      {:ok, test_state} = Game.change_station(game, :compton)

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

      %{starting_state: starting_state, test_state: test_state}
    end

    test "changes game state", context do
      assert context.test_state.rules.state == :in_transit
    end

    test "station is updated", context do
      assert context.test_state.station.station_name == :compton
    end

    test "does not decrement turns", context do
      assert context.test_state.rules.turns_left == context.starting_state.rules.turns_left
    end
  end

  describe ".change_station when not in game" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)
      Game.change_station(game, :compton)

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

      %{game: game}
    end

    test "returns rules error", context do
      assert Game.change_station(context.game, :hollywood) == :violates_current_rules
    end
  end

  describe ".end_transit when not in transit" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

      %{game: game}
    end

    test "returns rules error", context do
      assert Game.end_transit(context.game) == :violates_current_rules
    end
  end

  describe ".end transit when in transit" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)
      {:ok, starting_state} = Game.change_station(game, :beverly_hills)
      {:ok, test_state}     = Game.end_transit(game)

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

      %{starting_state: starting_state, test_state: test_state}
    end

    test "decrements turns", context do
      assert context.test_state.rules.turns_left < context.starting_state.rules.turns_left
    end

    test "changes state", context do
      assert context.test_state.rules.state == :in_game
    end

    test "station has not changed during transit", context do
      assert context.test_state.station.station_name == context.starting_state.station.station_name
    end
  end

  describe ".mug_player :fight - with 1 turn left" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)

      {:ok, state} = Game.change_station(game, :compton)
      end_rules = state |> Map.get(:rules) |> Map.put(:turns_left, 1)
      end_state = Map.put(state, :rules, end_rules)
      :sys.replace_state game, fn(_state) -> end_state end

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

      %{game: game}
    end

    test "returns error", context do
      assert Game.mug_player(context.game, :fight) == :not_enough_turns
    end
  end

  describe ".mug_player :fight - with no weapon" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)

      {:ok, state} = Game.change_station(game, :compton)

      {:ok, armed_player} = Player.buy_weapon state.player, :bat, 0
      starting_state      = Map.put(state, :player, armed_player)
      :sys.replace_state game, fn(_state) -> starting_state end

      {:ok, test_state} = Game.mug_player(game, :fight)

      on_exit fn ->
        GameSupervisor.stop_game "Frank"
      end

      %{starting_state: starting_state, test_state: test_state}
    end

    test "decrements turns", context do
      assert context.starting_state.rules.turns_left > context.test_state.rules.turns_left
    end

    test "state remains unchanged", context do
      assert context.test_state.rules.state == :in_transit
    end
  end

  describe ".mug_player :funds - with 0 funds" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)
      Game.change_station(game, :compton)

      on_exit fn ->
        GameSupervisor.stop_game("Frank")
      end

      %{game: game}
    end

    test "returns error", context do
      assert Game.mug_player(context.game, :funds) == :insufficient_funds
    end
  end

  describe ".mug_player :funds - with funds" do
    setup _context do
      {:ok, game} = GameSupervisor.start_game("Frank")
      Game.start_game(game)

      funds = 5000
      Game.buy_loan(game, funds, 0.1)

      {:ok, starting_state} = Game.change_station(game, :compton)
      {:ok, test_state}     = Game.mug_player(game, :funds)

      on_exit fn ->
        GameSupervisor.stop_game("Frank")
      end

      %{starting_state: starting_state, test_state: test_state}
    end

    test "decreases player funds", context do
      assert context.starting_state.player.funds > context.test_state.player.funds
    end

    test "does not decrease turns or change state", context do
      assert context.starting_state.rules.turns_left == context.test_state.rules.turns_left
      assert context.starting_state.rules.state == context.test_state.rules.state
    end
  end

  # Weapons --------------------------------------------------------------------


end
