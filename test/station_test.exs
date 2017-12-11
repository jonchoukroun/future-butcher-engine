defmodule FutureButcherEngine.StationTest do
  use ExUnit.Case
  alias FutureButcherEngine.Station

  test "Invalid station name returns error" do
    assert Station.new(:bullshit_name) == {:error, :invalid_station}
  end

  test "Valid station name creates station with market quantities and values" do
    {:ok, station} = Station.new(:downtown)
    assert station.station_name == :downtown
    assert is_list(station.market)
  end

end