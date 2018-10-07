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
      assert context.state.player.funds       == 5000
      assert context.state.player.debt        == 5000
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
    setup [:setup_game]

    test "Decrements turns", context do
      assert context.state.rules.turns_left == 24
    end

    test "Sets station to downtown", context do
      assert context.state.station.station_name == :downtown
      assert context.state.station.market       != nil
    end

    test "Player is capitalized", context do
      assert context.state.player.funds == 5000
      assert context.state.player.debt  == 5000
    end
  end


  # Debt/loans -----------------------------------------------------------------

  describe ".pay_debt" do
    setup [:setup_game, :increase_funds]

    test "should reduce funds and clear debt", context do
      Game.pay_debt(context.game)
      test_state = :sys.get_state(context.game)

      assert test_state.player.funds === 5000
      assert test_state.player.debt === 0
    end
  end

  describe ".pay_debt when debt is greater than funds" do
    setup [:setup_game, :decrease_funds]

    test "should return error if funds is less then debt", context do
      assert Game.pay_debt(context.game) === :insufficient_funds
    end
  end


  # Buy/sell cuts --------------------------------------------------------------


  # Travel/transit -------------------------------------------------------------

  describe ".change_station" do
    setup [:setup_game, :navigate_to_compton]

    test "should update game state", context do
      random_occurence_outcomes = [:mugging, :in_game]
      assert Enum.member?(random_occurence_outcomes, context.state.rules.state)
    end

    test "should update station name", context do
      assert context.state.station.station_name == :compton
    end

    test "should decrement turns left", context do
      assert context.state.rules.turns_left === 23
    end

    test "should accrue player debt", context do
      assert context.state.player.debt === 5750
    end

    # test "should return end game with no turns left", context do
    #   test_rules = %Rules{context.test_state.rules | turns_left: 0}
    #   :sys.replace_state context.game, fn _state -> %{context.test_state | rules: test_rules} end
    #
    #   {end_response, end_state} = Game.change_station(context.game, :hollywood)
    #
    #   assert end_response          === :game_over
    #   assert end_state.rules.state === :game_over
    # end
  end


  # Muggings -------------------------------------------------------------------

  describe ".fight_mugger with no weapon" do
    setup [:setup_game, :initiate_mugging, :lose_mugging]

    test "should impose turns penalty", context do
      assert context.base_state.rules.turns_left > context.test_state.rules.turns_left
    end

    test "should restore in_game state", context do
      assert context.test_state.rules.state === :in_game
    end
  end

  describe ".fight_mugger and win" do
    setup [:setup_game, :initiate_mugging, :win_mugging]

    test "should restore in_game state", context do
      assert context.test_state.rules.state === :in_game
    end

    test "should incur no turns penalty", context do
      assert context.base_state.rules.turns_left === context.test_state.rules.turns_left
    end
  end


  # Name setups ================================================================

    defp setup_game(_context) do
      {:ok, game} = GameSupervisor.start_game("Frank")
      {:ok, state} = Game.start_game(game)

      on_exit fn -> GameSupervisor.stop_game "Frank" end

      %{game: game, state: state}
    end

    defp increase_funds(context) do
      test_player = %Player{context.state.player | funds: 10000}
      :sys.replace_state(context.game, fn _state -> %{context.state | player: test_player} end)

      %{game: context.game, state: :sys.get_state(context.game)}
    end

    defp decrease_funds(context) do
      test_player = %Player{context.state.player | funds: 100}
      :sys.replace_state(context.game, fn _state -> %{context.state | player: test_player} end)

      %{game: context.game, state: :sys.get_state(context.game)}
    end

    defp navigate_to_compton(context) do
      Game.change_station(context.game, :compton)
      %{game: context.game, state: :sys.get_state(context.game)}
    end

    defp initiate_mugging(context) do
      test_rules = %Rules{turns_left: 10, state: :mugging}
      :sys.replace_state(context.game, fn _state -> %{context.state | rules: test_rules} end)
      %{game: context.game, state: :sys.get_state(context.game)}
    end

    defp lose_mugging(context) do
      Game.fight_mugger(context.game)
      %{game: context.game, base_state: context.state, test_state: :sys.get_state(context.game)}
    end

    defp win_mugging(context) do
      add_weapon(context)
      Game.fight_mugger(context.game)

      current_turns = context.state.rules.turns_left

      case :sys.get_state(context.game).rules.turns_left do
        ^current_turns ->
          %{game: context.game, base_state: context.state, test_state: :sys.get_state(context.game)}

        _ ->
          win_mugging(context)
      end
    end

    defp add_weapon(context) do
      armed_player = %Player{context.state.player | weapon: :hockey_stick}
      :sys.replace_state(context.game, fn _state -> %{context.state | player: armed_player} end)

      %{game: context.game, state: :sys.get_state(context.game)}
    end

end
