defmodule FutureButcherEngine.StationTest do
  use ExUnit.Case
  alias FutureButcherEngine.Station

  describe ".new - bell gardens" do
    setup _context do
      %{station: Station.new(:bell_gardens, 20)}
    end

    test "should generate store", context do
      assert is_map(context.station.store)
    end

    test "should not generate market", context do
      assert is_nil(context.station.market)
    end
  end

  describe ".new - other stations" do
    setup _context do
      %{station: Station.new(:compton, 24)}
    end

    test "generates market quantities and values", context do
      assert context.station.station_name === :compton
      assert is_map(context.station.market)
    end

    test "does not generate a store", context do
      assert context.station.store == nil
    end
  end

  test ".new - invalid station name" do
    assert Station.new(:bullshit_name, 25) == {:error, :invalid_station}
  end

end
