defmodule FutureButcherEngine.StationTest do
  use ExUnit.Case
  alias FutureButcherEngine.{Station}


  # New station ----------------------------------------------------------------

  describe ".new - bell gardens with more than 20 turns left" do
    test "should return error" do
      assert Station.new(:bell_gardens, 24) === {:error, :store_not_open}
    end
  end

  describe ".new - bell gardens" do
    setup [:get_bell_gardens]

    test "should generate store", context do
      assert is_map(context.station.store)
    end

    test "should not generate market", context do
      assert is_nil(context.station.market)
    end
  end

  describe ".new" do
    setup [:get_compton]

    test "should update station name", context do
      assert context.station.station_name === :compton
    end

    test "should generate market", context do
      assert is_map(context.station.market)
    end

    test "should not generate store", context do
      assert context.station.store == nil
    end
  end

  test ".new - invalid station name" do
    assert Station.new(:bullshit_name, 25) == {:error, :invalid_station}
  end


  # Random encounters ----------------------------------------------------------

  describe ".random_encounter bell gardens" do
    test "should end transit" do
      assert Station.random_encounter(20, 20, :bell_gardens) === {:ok, :end_transit}
    end
  end

  describe ".random_encounter last turn" do
    test "should end transit" do
      assert Station.random_encounter(20, 0, :beverly_bills) === {:ok, :end_transit}
    end
  end

  describe ".random_encounter" do
    test "should either end transit or initiate mugging" do
      random_outcomes = [:mugging, :end_transit]
      {:ok, test_outcome} = Station.random_encounter(20, 10, :venice_beach)
      assert Enum.member?(random_outcomes, test_outcome)
    end
  end


  # Mugging probabilities ------------------------------------------------------

  describe ".calculate_mugging_probability" do

    test "at compton with default pack should return P(m) = 0.4" do
      assert Station.calculate_mugging_probability(20, 20, :compton) === 0.45
    end

    test "at compton with additional pack space should return P(m) = 0.6" do
      assert Station.calculate_mugging_probability(40, 20, :compton) === 0.65
    end

    test "should return 3-digit float" do
      assert is_float(Station.calculate_mugging_probability(20, 10, :beverly_hills))
      assert is_float(Station.calculate_mugging_probability(20, 10, :venice_beach))
      assert is_float(Station.calculate_mugging_probability(50, 2, :downtown))
      assert is_float(Station.calculate_mugging_probability(30, 24, :hollywood))
    end
  end

  # Named setups ===============================================================

  defp get_compton(_context) do
    %{station: Station.new(:compton, 24)}
  end

  defp get_bell_gardens(_context) do
    %{station: Station.new(:bell_gardens, 20)}
  end

end
