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
    player = Player.new(100, 1000)
    assert Player.adjust_pack(player, :ribs, 20, 1000, :buy) == {
      :error, :insufficient_funds}
  end

  test "Buying with insufficient space returns error" do
    player = Player.new(100, 1000)
    assert Player.adjust_pack(player, :ribs, 100, 1, :buy) == {
      :error, :insufficient_pack_space}

    {:ok, player} = Player.adjust_pack(player, :ribs, 10, 10, :buy)
    assert Player.adjust_pack(player, :ribs, 11, 10, :buy) == {
      :error, :insufficient_pack_space}
  end

  test "Valid purchase increases owned cut and decreases funds" do
    player = Player.new(100, 1000)
    {:ok, player} = Player.adjust_pack(player, :loin, 5, 100, :buy)
    assert Map.get(player.pack, :loin) == 5
    assert player.funds == 500
  end

  test "Decreasing fund by more than available zeroes out funds" do
    player = Player.new(100, 1000)
    {:ok, player} = Player.adjust_funds(player, 2000, :decrease)
    assert player.funds == 0
  end

  test "Decreasing funds by less than available reduces funds" do
    player = Player.new(100, 1000)
    {:ok, player} = Player.adjust_funds(player, 500, :decrease)
    assert player.funds == 500
  end

  test "Increasing funds raises player's funds by amount" do
    player = Player.new(100, 1000)
    {:ok, player} = Player.adjust_funds(player, 500, :increase)
    assert player.funds == 1500
  end

  # test "Repaying debt when less than funds clears debts and reduces funds" do
  #   player = Player.new(100, 1000)
  #   {:ok, player} = Player.adjust_funds(player, 1000, :sell)
  #   assert player.funds > player.debt

  #   {:ok, player} = Player.repay_debt(player)
  #   assert player.debt == 0
  #   assert player.funds == 1000
  # end

  # test "Repaying debt when more than funds returns error" do
  #   player = Player.new(100, 1000)
  #   refute player.funds > player.debt
  #   {:ok, player} = Player.adjust_funds(player, 100, :buy)

  #   assert Player.repay_debt(player) == {:error, :insufficient_funds}
  # end

  # test "Hurting player by more than current health results in death" do
  #   player = Player.new(100, 1000)
  #   assert Player.adjust_health(player, 200, :hurt) == {:ok, :player_dead}
  # end

  # test "Healing player by more than max health returns max health" do
  #   player = Player.new(50, 1000)
  #   {:ok, player} = Player.adjust_health(player, 100, :heal)
  #   assert player.health == 100
  # end

  # test "Hurting player decreases health by expected amount" do
  #   player = Player.new(100, 1000)
  #   {:ok, player} = Player.adjust_health(player, 20, :hurt)
  #   assert player.health == 80
  # end

  # test "Healing player increases health by expected amount" do
  #   player = Player.new(40, 1000)
  #   {:ok, player} = Player.adjust_health(player, 20, :heal)
  #   assert player.health == 60
  # end
end