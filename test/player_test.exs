defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player

  test "Player.new/2 when health exceeds max returns error" do
    assert Player.new(200, 1000) == {:error, :invalid_player_values}
  end

  test "Player.new/2 when funds is invalid returns error" do
    assert Player.new(100, 0) == {:error, :invalid_player_values}
  end

  test "Buying with insufficient funds returns error" do
    {:ok, player} = Player.new(100, 1000)
    assert Player.adjust_funds(player, 1001, :buy) == {
      :error, :insufficient_funds}
  end

  test "Buying with sufficient funds returns expected values" do
    {:ok, player} = Player.new(100, 1000)
    {:ok, player} = Player.adjust_funds(player, 100, :buy)
    assert player.funds == 900
  end

  test "Selling returns expected values" do
    {:ok, player} = Player.new(100, 1000)
    {:ok, player} = Player.adjust_funds(player, 100, :sell)
    assert player.funds == 1100
  end

  test "Hurting player by more than current health results in death" do
    {:ok, player} = Player.new(100, 1000)
    assert Player.adjust_health(player, 200, :hurt) == {:ok, :player_dead}
  end

  test "Healing player by more than max health returns max health" do
    {:ok, player} = Player.new(50, 1000)
    {:ok, player} = Player.adjust_health(player, 100, :heal)
    assert player.health == 100
  end
end