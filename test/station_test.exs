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

end
