defmodule FutureButcherEngine.StationTest do
  use ExUnit.Case
  alias FutureButcherEngine.Station

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


  # Named setups ===============================================================

  def get_compton(_context) do
    %{station: Station.new(:compton, 24)}
  end

  def get_bell_gardens(_context) do
    %{station: Station.new(:bell_gardens, 20)}
  end

end
