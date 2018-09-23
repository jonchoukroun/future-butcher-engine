defmodule FutureButcherEngine.StationTest do
  use ExUnit.Case
  alias FutureButcherEngine.Station

  describe ".new - venice beach" do
    setup _context do
      %{station: Station.new(:venice_beach, 24)}
    end

    test "generates store", context do
      assert is_map(context.station.store)
    end
  end

  describe ".new - other stations" do
    setup _context do
      %{station: Station.new(:compton, 24)}
    end

    test "generates market quantities and values", context do
      assert context.station.station_name === :compton
      assert is_map(context.station.market)
      assert Map.keys(context.station.market.flank) == [:price, :quantity]
    end

    test "does not generate a store", context do
      assert context.station.store == nil
    end
  end

  test ".new - invalid station name" do
    assert Station.new(:bullshit_name, 25) == {:error, :invalid_station}
  end

  describe ".generate_entry_fee" do
    test "compton should generate no fee" do
      assert Station.generate_entry_fee(:compton, 10) === {:ok, 0}
    end

    test "other stations should increase in price over time" do
      {:ok, early_fee} = Station.generate_entry_fee(:beverly_hills, 24)
      {:ok, late_fee} = Station.generate_entry_fee(:beverly_hills, 10)
      assert early_fee < late_fee
    end
  end

  test "Market generated at low crime station in early game is reduced in range" do
    station = Station.new(:beverly_hills, 25)
    range   = 0.6

    expected_flank_max = 20 - (20 * ((1 - range) / 2)) |> round()
    expected_flank_min = 20 * ((1 - range) / 2) + 1 |> round()
    expected_heart_max = 10 - (10 * ((1 - range) / 2)) |> round()
    expected_heart_min = 10 * ((1 - range) / 2) + 1 |> round()
    expected_ribs_max  = 40 - (40 * ((1 - range) / 2)) |> round()
    expected_ribs_min  = 40 * ((1 - range) / 2) + 1 |> round()

    assert Enum.member? (expected_flank_min..expected_flank_max), station.market.flank.quantity
    assert Enum.member? (expected_heart_min..expected_heart_max), station.market.heart.quantity
    assert Enum.member? (expected_ribs_min..expected_ribs_max), station.market.ribs.quantity
  end

end
