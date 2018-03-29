defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player

  test "Buying with insufficient funds returns error" do
    player = Player.new("Frank", 100, 1000)
    assert Player.buy_cut(player, :ribs, 20, 1300) == {
      :error, :insufficient_funds}
  end

  test "Buying with insufficient space returns error" do
    player = Player.new("Frank", 100, 1000)
    assert Player.buy_cut(player, :ribs, 100, 1) == {
      :error, :insufficient_pack_space}

    {:ok, player} = Player.buy_cut(player, :ribs, 10, 10)
    assert Player.buy_cut(player, :ribs, 11, 10) == {
      :error, :insufficient_pack_space}
  end

  test "Valid purchase increases owned cut and decreases funds" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.buy_cut(player, :loin, 5, 100)
    assert Map.get(player.pack, :loin) == 5
    assert player.funds == 900
  end

  test "Selling more cuts than owned returns error" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.buy_cut(player, :heart, 5, 10)
    assert Player.sell_cut(player, :heart, 6, 10)
    assert Player.sell_cut(player, :flank, 3, 10)
  end

  test "Valid sale decreases owned cut and increases funds" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.buy_cut(player, :flank, 5, 10)
    {:ok, player} = Player.sell_cut(player, :flank, 3, 20)
    assert Map.get(player.pack, :flank) == 2
    assert player.funds == 1010
  end

  test "Decreasing fund by more than available zeroes out funds" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 2000, :decrease)
    assert player.funds == 0
  end

  test "Decreasing funds by less than available reduces funds" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 500, :decrease)
    assert player.funds == 500
  end

  test "Increasing funds raises player's funds by amount" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 500, :increase)
    assert player.funds == 1500
  end

  test "Accruing debt raises debt amount by 15% when debt is > 0" do
    player = Player.new("Frank", 100, 1000)
    assert player.debt > 0

    {:ok, player} = Player.accrue_debt(player)
    assert player.debt == (1000 * 1.15)
  end

  test "Debt doesn't accrue when paid off" do
    player = Player.new("Frank", 100, 1000)
    assert player.debt > 0

    {:ok, player} = Player.adjust_funds(player, 1000, :increase)
    {:ok, player} = Player.pay_debt(player, player.debt)

    assert Player.accrue_debt(player) == {:ok, player}
    assert player.debt == 0
  end

  test "Paying debt with amount less debt reduces funds and debt" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 1000, :increase)
    assert player.funds > player.debt

    amount = 100
    assert amount < player.funds
    assert amount < player.debt

    {:ok, player} = Player.pay_debt(player, amount)
    assert player.debt == 900
    assert player.funds == 1900
  end

  test "Paying debt with amount equal to debt clears debt" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 1000, :increase)
    assert player.funds > player.debt

    amount = player.debt
    assert amount < player.funds

    {:ok, player} = Player.pay_debt(player, amount)
    assert player.debt == 0
    assert player.funds == 1000
  end

  test "Paying debt with amount greater than funds returns error" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 100, :decrease)
    refute player.funds > player.debt

    amount = player.funds

    assert Player.pay_debt(player, amount) == {:error, :insufficient_funds}
  end

  test "Paying debt with amount greater than debt clears debt" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_funds(player, 1000, :increase)
    assert player.funds > player.debt

    amount = 1100
    assert amount < player.funds

    {:ok, player} = Player.pay_debt(player, amount)
    assert player.debt == 0
    assert player.funds == 1000
  end

  test "Hurting player by more than current health results in death" do
    player = Player.new("Frank", 100, 1000)
    assert Player.adjust_health(player, 200, :hurt) == {:ok, :player_dead}
  end

  test "Healing player by more than max health returns max health" do
    player = Player.new("Frank", 50, 1000)
    {:ok, player} = Player.adjust_health(player, 100, :heal)
    assert player.health == 100
  end

  test "Hurting player decreases health by expected amount" do
    player = Player.new("Frank", 100, 1000)
    {:ok, player} = Player.adjust_health(player, 20, :hurt)
    assert player.health == 80
  end

  test "Healing player increases health by expected amount" do
    player = Player.new("Frank", 40, 1000)
    {:ok, player} = Player.adjust_health(player, 20, :heal)
    assert player.health == 60
  end
end