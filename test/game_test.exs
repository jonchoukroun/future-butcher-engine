defmodule GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.{Game, GameSupervisor}

  test "Initializing game creates named player with no finances" do
    {:ok, state} = Game.init("Frank")
    assert state.player.player_name == "Frank"
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

  test "Starting game decrements turns" do
    {:ok, game} = GameSupervisor.start_game("Frank")
    {:ok, state} = Game.start_game(game)
    assert state.rules.turns_left == 24
    GameSupervisor.stop_game("Frank")
  end

  test ".change_station" do
    {:ok, game} = GameSupervisor.start_game("Frank")

    {:ok, starting_state} = Game.start_game(game)
    assert starting_state.rules.state          == :in_game
    assert starting_state.rules.turns_left     == 24
    assert starting_state.station.station_name == :downtown

    {:ok, transit_state} = Game.change_station(game, :compton)
    assert transit_state.rules.state          == :in_transit
    assert transit_state.rules.turns_left     == 24
    assert transit_state.station.station_name == :compton

    {:ok, arrival_state} = Game.end_transit(game)
    assert arrival_state.rules.state          == :in_game
    assert arrival_state.rules.turns_left     == 23
    assert arrival_state.station.station_name == :compton

    GameSupervisor.stop_game("Frank")
  end

  test ".mug player :fight - with 1 turn left" do
    {:ok, game} = GameSupervisor.start_game("Frank")

    Game.start_game(game)
    {:ok, state} = Game.change_station(game, :venice_beach)
    end_rules = state |> Map.get(:rules) |> Map.put(:turns_left, 1)
    end_state = Map.put(state, :rules, end_rules)

    :sys.replace_state game, fn(_state) -> end_state end
    assert end_state.rules.turns_left == 1

    assert Game.mug_player(game, :fight) == :too_few_turns_left

    GameSupervisor.stop_game("Frank")
  end

  test ".mug player :fight - with no weapon" do
    {:ok, game} = GameSupervisor.start_game("Frank")
    Game.start_game(game)

    {:ok, starting_state} = Game.change_station(game, :compton)
    assert starting_state.rules.turns_left == 24

    {:ok, test_state} = Game.mug_player(game, :fight)
    assert test_state.rules.state == :in_transit
    assert starting_state.rules.turns_left > test_state.rules.turns_left

    GameSupervisor.stop_game("Frank")
  end

  test ".mug player :funds - with no money" do
    {:ok, game} = GameSupervisor.start_game("Frank")
    Game.start_game(game)

    Game.change_station(game, :compton)

    assert Game.mug_player(game, :funds) == :insufficient_funds

    GameSupervisor.stop_game("Frank")
  end


  test ".mug player :funds" do
    {:ok, game} = GameSupervisor.start_game("Frank")
    Game.start_game(game)

    funds = 5000
    Game.buy_loan(game, funds, 0.1)
    Game.change_station(game, :compton)

    {:ok, state} = Game.mug_player(game, :funds)
    assert state.player.funds < funds

    GameSupervisor.stop_game("Frank")
  end

end
