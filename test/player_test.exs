defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player

  test "New players created with an empty pack, and no financials" do
    player = Player.new("Frank")
    assert player.player_name == "Frank"
    assert player.funds       == 0
    assert player.debt        == 0
    assert player.rate        == 0

    player.pack
    |> Map.keys()
    |> Enum.each(fn (c) -> assert(Map.fetch!(player.pack, c) == 0) end)
  end

  test "Buying loan with integer rate converts to float and initialize finances" do
    player = Player.new("Frank")
    {:ok, player} = Player.buy_loan(player, 5000, 2)

    assert player.funds == 5000
    assert player.debt  == 5000
    assert player.rate  == 2.0
  end

  test "Buying loan with existing debt return error" do
    player = Player.new("Frank")
    {:ok, player} = Player.buy_loan(player, 5000, 0.5)

    assert Player.buy_loan(player, 1000, 0.1) == {:error, :already_has_debt}
  end

  test "Debt accrues on debt by rate rate" do
    player = Player.new("Frank")
    debt   = 5000
    rate   = 0.5
    {:ok, player} = Player.buy_loan(player, debt, rate)
    {:ok, player} = Player.accrue_debt(player)

    assert player.debt == debt * (1 + rate)
  end

  test "Buying with insufficient funds returns error" do
    player = Player.new("Frank")
    assert Player.buy_cut(player, :ribs, 20, 1300) == {:error, :insufficient_funds}
  end

  test "Buying with insufficient space returns error" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    assert Player.buy_cut(player, :ribs, 100, 1) == {:error, :insufficient_pack_space}

    {:ok, player} = Player.buy_cut(player, :ribs, 10, 10)
    assert Player.buy_cut(player, :ribs, 11, 10) == {:error, :insufficient_pack_space}
  end

  test "Valid purchase increases owned cut and decreases funds" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.buy_cut(player, :loin, 5, 100)
    assert Map.get(player.pack, :loin) == 5
    assert player.funds == 4900
  end

  test "Selling more cuts than owned returns error" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.buy_cut(player, :heart, 5, 10)
    assert Player.sell_cut(player, :heart, 6, 10) == {:error, :insufficient_cuts}
  end

  test "Valid sale decreases owned cut and increases funds" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.buy_cut(player, :flank, 5, 10)
    {:ok, player} = Player.sell_cut(player, :flank, 3, 20)
    assert Map.get(player.pack, :flank) == 2
    assert player.funds == 5010
  end

  test "Decreasing fund by more than available zeroes out funds" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.adjust_funds(player, :decrease, 8000)
    assert player.funds == 0
  end

  test "Decreasing funds by less than available reduces funds" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.adjust_funds(player, :decrease, 500)
    assert player.funds == 4500
  end

  test "Increasing funds raises player's funds by amount" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.adjust_funds(player, :increase, 500)
    assert player.funds == 5500
  end

  test "Debt doesn't accrue when paid off" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    assert player.debt > 0

    {:ok, player} = Player.adjust_funds(player, :increase, 1000)
    {:ok, player} = Player.pay_debt(player, player.debt)

    assert Player.accrue_debt(player) == {:ok, player}
    assert player.debt == 0
  end

  test "Paying debt with amount less debt reduces funds and debt but keeps rate" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)

    {:ok, player} = Player.pay_debt(player, 1000)
    assert player.debt  == 4000
    assert player.funds == 4000
    assert player.rate  == 0.5
  end

  test "Paying debt in full clears debt and rate rate" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.adjust_funds(player, :increase, 1000)

    {:ok, player} = Player.pay_debt(player, 5000)
    assert player.funds == 1000
    assert player.debt  == 0
    assert player.rate  == 0.0
  end

  test "Paying debt with amount greater than funds returns error" do
    {:ok, player} = Player.buy_loan(Player.new("Frank"), 5000, 0.5)
    {:ok, player} = Player.adjust_funds(player, :decrease, 100)
    refute player.funds > player.debt

    amount = player.funds

    assert Player.pay_debt(player, amount) == {:error, :insufficient_funds}
  end

end
