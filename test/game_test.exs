defmodule GameTest do
  use ExUnit.Case
  alias FutureButcherEngine.{Game, GameSupervisor, Rules, Player, Station}


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
      assert context.state.rules.turns_left == 24
      assert context.state.rules.state      == :initialized
    end

    test "does not set station", context do
      assert context.state.station == nil
    end
  end

  describe ".start_game" do
    setup [:setup_game]

    test "Sets station to downtown", context do
      assert context.state.station.station_name == :compton
      assert context.state.station.market       != nil
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
    setup [:setup_game, :navigate_to_hollywood]

    test "should update game state", context do
      random_occurence_outcomes = [:mugging, :in_game]
      assert Enum.member?(random_occurence_outcomes, context.test_state.rules.state)
    end

    test "should update station name", context do
      assert context.test_state.station.station_name == :hollywood
    end

    test "should decrement turns left", context do
      assert context.state.rules.turns_left - context.test_state.rules.turns_left === 2
    end

    test "should accrue player debt", context do
      expected_debt = 5000 * :math.pow(1.05, Station.get_travel_time(:hollywood)) |> round()
      assert context.test_state.player.debt === expected_debt
    end

  end

  describe ".change_station beverly_hills" do
    setup [:setup_game, :navigate_to_beverly_hills]

    test "should decrement turns left", context do
      assert context.test_state.rules.turns_left < context.state.rules.turns_left
    end
  end

  describe ".change_turns with insufficient turns left" do
    setup [:setup_game, :reduce_turns]

    test "should return error", context do
      assert Game.change_station(context.game, :beverly_hills) === :insufficient_turns
    end
  end


  # Muggings -------------------------------------------------------------------

  describe ".fight_mugger with no weapon" do
    setup [:setup_game, :initiate_mugging, :lose_mugging]

    test "should impose turns penalty", context do
      assert context.state.rules.turns_left > context.test_state.rules.turns_left
    end

    test "should accrue debt for lost turns", context do
      turns_lost = context.state.rules.turns_left - context.test_state.rules.turns_left
      base_debt = context.state.player.debt
      expected_debt = base_debt * :math.pow(1.05, turns_lost) |> round()
      assert context.test_state.player.debt === expected_debt
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
      assert context.state.rules.turns_left === context.test_state.rules.turns_left
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

    defp navigate_to_hollywood(context) do
      Game.change_station(context.game, :hollywood)
      %{game: context.game, test_state: :sys.get_state(context.game)}
    end

    defp navigate_to_beverly_hills(context) do
      Game.change_station(context.game, :beverly_hills)
      %{game: context.game, test_state: :sys.get_state(context.game)}
    end

    defp initiate_mugging(context) do
      test_rules = %Rules{turns_left: 10, state: :mugging}
      :sys.replace_state(context.game, fn _state -> %{context.state | rules: test_rules} end)
      %{game: context.game, state: :sys.get_state(context.game)}
    end

    defp lose_mugging(context) do
      Game.fight_mugger(context.game)
      %{game: context.game, test_state: :sys.get_state(context.game)}
    end

    defp win_mugging(context) do
      add_weapon(context)
      Game.fight_mugger(context.game)

      current_turns = context.state.rules.turns_left

      case :sys.get_state(context.game).rules.turns_left do
        ^current_turns ->
          %{game: context.game, test_state: :sys.get_state(context.game)}

        _ ->
          win_mugging(context)
      end
    end

    defp add_weapon(context) do
      armed_player = %Player{context.state.player | weapon: :hockey_stick}
      :sys.replace_state(context.game, fn _state -> %{context.state | player: armed_player} end)

      %{game: context.game, state: :sys.get_state(context.game)}
    end

    defp reduce_turns(context) do
      rules = %Rules{context.state.rules | turns_left: 2}
      state = :sys.replace_state(context.game, fn _state -> %{context.state | rules: rules} end)
      %{game: context.game, test_state: state}
    end

end
