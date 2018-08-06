defmodule FutureButcherEngine.StationTest do
  use ExUnit.Case
  alias FutureButcherEngine.Station

  test "Invalid station name returns error" do
    assert Station.new(:bullshit_name, 25) == {:error, :invalid_station}
  end

  test "Valid station name creates station with market quantities and values" do
    station = Station.new(:downtown, 25)
    assert station.station_name == :downtown
    assert is_map(station.market)
    assert Map.keys(station.market.flank) == [:price, :quantity]
    assert station.market |> Map.keys() |> Enum.count() == 5
  end

  test "Market generated at low crime station in early game is reduced in range" do
    station = Station.new(:beverly_hills, 25)
    range   = 0.6

    expected_flank_max = 20 - (20 * ((1 - range) / 2)) |> round()
    expected_flank_min = 20 * ((1 - range) / 2) + 1 |> round()
    expected_heart_max = 10 - (10 * ((1 - range) / 2)) |> round()
    expected_heart_min = 10 * ((1 - range) / 2) + 1 |> round()
    expected_loin_max  = 45 - (45 * ((1 - range) / 2)) |> round()
    expected_loin_min  = 45 * ((1 - range) / 2) + 1 |> round()
    expected_ribs_max  = 40 - (40 * ((1 - range) / 2)) |> round()
    expected_ribs_min  = 40 * ((1 - range) / 2) + 1 |> round()
    expected_liver_max = 100 - (100 * ((1 - range) / 2)) |> round()
    expected_liver_min = 100 * ((1 - range) / 2) + 1 |> round()

    assert Enum.member? (expected_flank_min..expected_flank_max), station.market.flank.quantity
    assert Enum.member? (expected_heart_min..expected_heart_max), station.market.heart.quantity
    assert Enum.member? (expected_loin_min..expected_loin_max), station.market.loin.quantity
    assert Enum.member? (expected_ribs_min..expected_ribs_max), station.market.ribs.quantity
    assert Enum.member? (expected_liver_min..expected_liver_max), station.market.liver.quantity
  end

end
