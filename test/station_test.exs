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
      packs = Enum.to_list(20..60//10)
      for station <- FutureButcherEngine.Station.station_names(), pack <- packs do
        assert Station.random_encounter(pack, 0, station) === {:ok, :end_transit}
      end
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
    test "pack size should increase probability" do
      packs = Enum.to_list(20..60//10)
      for station <- Station.station_names() do
        probabilities = packs
          |> Enum.map(& Station.calculate_mugging_probability(&1, station))
        assert Enum.sort(packs) === packs
      end
    end

    test "should return a float" do
      packs = Enum.to_list(20..60//10)
      for station <- Station.station_names(), pack <- packs do
        if station !== :bell_gardens do
          assert is_float(Station.calculate_mugging_probability(pack, station))
        end
      end
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
