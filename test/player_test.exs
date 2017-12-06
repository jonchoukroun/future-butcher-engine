defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player

  test "Player.new/2 when health exceeds max returns error" do
    assert Player.new(200, 1000) == {:error, :invalid_player_values}
  end

  test "Player.new/2 when funds is invalid returns error" do
    assert Player.new(100, 0) == {:error, :invalid_player_values}
  end
end