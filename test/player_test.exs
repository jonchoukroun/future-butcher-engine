defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player


  # New player ----------------------------------------------------------------

  test "New players created with an empty pack, and no capital or weapon" do
    player = Player.new("Frank")
    assert player.player_name == "Frank"
    assert player.funds       == 0
    assert player.debt        == 0
    assert player.rate        == 0
    assert player.pack_space  == 20
    assert player.weapon      == nil

    player.pack
    |> Map.keys()
    |> Enum.each(fn (c) -> assert(Map.fetch!(player.pack, c) == 0) end)
  end


  # Packs ----------------------------------------------------------------------

  describe ".buy_pack" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.adjust_funds(:increase, 3000)
      %{player: player}
    end

    test "with less space than current pack", context do
      assert Player.buy_pack(context.player, 19, 100) == {:error, :no_pack_upgrade}
    end

    test "with insufficient funds", context do
      assert Player.buy_pack(context.player, 25, 5000) == {:error, :insufficient_funds}
    end

    test "with more space", context do
      {:ok, test_player} = Player.buy_pack(context.player, 25, 500)
      assert test_player.pack_space == 25
      assert test_player.funds      == 2500
    end
  end


  # Debt/Loans -----------------------------------------------------------------

  describe ".accrue_debt" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with no debt does nothing", context do
      {:ok, test_player} = Player.accrue_debt(context.player)
      assert test_player == context.player
    end

    test "with debt raises debt by interest rate amount", context do
      {:ok, player} = Player.buy_loan(context.player, 5000, 0.2)
      {:ok, test_player} = Player.accrue_debt(player)
      assert test_player.debt == 6000
    end
  end

  describe ".buy_loan" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with loan rate as integer converts to float", context do
      {:ok, test_player} = Player.buy_loan(context.player, 1000, 2)
      assert test_player.debt == 1000
      assert test_player.rate == 2.0
    end

    test "with existing debt returns error", context do
      {:ok, test_player} = Player.buy_loan(context.player, 1000, 0.4)
      assert Player.buy_loan(test_player, 1000, 0.25) == {:error, :already_has_debt}
    end
  end

  describe ".pay_debt" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.buy_loan(1000, 0.1)
      {:ok, player} = Player.adjust_funds(player, :increase, 2000)
      %{player: player}
    end

    test "with full amount clears debt and rate", context do
      {:ok, test_player} = Player.pay_debt(context.player, 1000)
      assert test_player.funds == 2000
      assert test_player.debt  == 0
      assert test_player.rate  == 0.0
    end

    test "with amount greater than funds returns error", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 2500)
      assert Player.pay_debt(test_player, 1000) == {:error, :insufficient_funds}
    end
  end


  # Buy/Sell Cuts --------------------------------------------------------------

  describe ".buy_cut" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.adjust_funds(:increase, 5000)
      %{player: player}
    end

    test "with insufficient funds returns error", context do
      assert Player.buy_cut(context.player, :loin, 4, 10_000) == {:error, :insufficient_funds}
    end

    test "with insufficient space returns error", context do
      assert Player.buy_cut(context.player, :ribs, 100, 3000) == {:error, :insufficient_pack_space}
    end

    test "with valid args increases cuts and decreases funds", context do
      {:ok, test_player} = Player.buy_cut(context.player, :heart, 10, 1000)
      assert test_player.pack.heart == 10
      assert test_player.funds      == 4000
    end
  end

  describe ".sell_cut" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.adjust_funds(:increase, 2000)
      {:ok, player} = Player.buy_cut(player, :ribs, 5, 500)
      %{player: player}
    end

    test "with more cuts than owned", context do
      assert Player.sell_cut(context.player, :ribs, 6, 500) == {:error, :insufficient_cuts}
    end

    test "with valid args decreases cut and increases funds", context do
      {:ok, test_player} = Player.sell_cut(context.player, :ribs, 5, 1000)

      assert test_player.pack.ribs == 0
      assert test_player.funds     == 2500
    end
  end


  # Weapons --------------------------------------------------------------------

  describe ".buy_weapon with no current weapon" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.adjust_funds(:increase, 3000)
      %{player: player}
    end

    test "with sufficient funds and pack space adds weapon and decreases funds", context do
      {:ok, test_player } = Player.buy_weapon(context.player, :machete, 1000)
      assert test_player.funds  == 2000
      assert test_player.weapon == :machete
    end

    test "with insufficient funds returns error", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 2000)
      assert Player.buy_weapon(test_player, :machete, 2000) == {:error, :insufficient_funds}
    end

    test "with invalid weapon type returns error", context do
      assert Player.buy_weapon(context.player, :cat, 100) == {:error, :invalid_weapon_type}
    end
  end

  describe ".buy_weapon with existing weapon" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.buy_weapon(:hedge_clippers, 0)
      %{player: player}
    end

    test "returns error", context do
      assert Player.buy_weapon(context.player, :box_cutter, 0) == {:error, :already_owns_weapon}
    end
  end

  describe ".replace_weapon with no existing weapon" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "returns error", context do
      assert Player.replace_weapon(context.player, :machete, 0, 0) == {:error, :no_weapon_owned}
    end
  end

  describe ".replace_weapon with existing weapon" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.adjust_funds(:increase, 5000)
      {:ok, player} = Player.buy_weapon(player, :box_cutter, 1000)
      %{player: player}
    end

    test "with insufficient funds + trade-in value returns error", context do
      assert Player.replace_weapon(context.player, :hedge_clippers, 6000, 100) ==
        {:error, :insufficient_funds}
    end

    test "with same weapon as current weapon returns error", context do
      assert Player.replace_weapon(context.player, :box_cutter, 0, 0) ==
        {:error, :same_weapon_type}
    end

    test "with cheaper weapon than current weapon replaces weapon and adjusts funds", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :brass_knuckles, 500, 200)
      assert test_player.weapon == :brass_knuckles
      assert test_player.funds  == 3700
    end

    test "with valid args replaces weapon and adjusts funds", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :machete, 1000, 200)
      assert test_player.weapon == :machete
      assert test_player.funds  == 3200
    end

    test "with insufficient funds but enough value replaces weapon and adjusts funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 4000)
      assert test_player.funds == 0

      {:ok, test_player} = Player.replace_weapon(test_player, :hedge_clippers, 500, 1000)
      assert test_player.weapon == :hedge_clippers
      assert test_player.funds  == 500
    end
  end


  # Muggings -------------------------------------------------------------------

  describe ".mug_player funds" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.adjust_funds(:increase, 1000)
      %{player: player}
    end

    test "with no funds returns error", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 1000)
      assert Player.mug_player(test_player, :funds) == {:error, :insufficient_funds}
    end

    test "with funds decreases funds", context do
      {:ok, test_player} = Player.mug_player(context.player, :funds)
      assert test_player.funds < context.player.funds
    end
  end

  describe ".mug_player cuts" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with no cuts returns error", context do
      assert Player.mug_player(context.player, :cuts) == {:error, :no_cuts_owned}
    end

    test "with 1 cut type owned removes all cuts", context do
      {:ok, test_player} = Player.buy_cut(context.player, :heart, 3, 0)
      {:ok, test_player} = Player.mug_player(test_player, :cuts)
      assert test_player.pack.heart == 0
    end

    test "with multiple cut types owned removes all of 1 cut type", context do
      {:ok, player} = Player.buy_cut(context.player, :heart, 3, 0)
      {:ok, player} = Player.buy_cut(player, :loin, 2, 0)
      {:ok, player} = Player.buy_cut(player, :ribs, 5, 0)

      {:ok, test_player} = Player.mug_player(player, :cuts)
      assert Map.keys(test_player.pack)
             |> Enum.filter(fn(cut) -> test_player.pack[cut] > 0 end)
             |> Enum.count == 2
    end
  end

  describe ".mug_player" do
    test "with invalid mugging response" do
      player = Player.new "Frank"
      assert Player.mug_player(player, :fish) == {:error, :invalid_mugging_response}
    end
  end

  # Funds ----------------------------------------------------------------------

  describe ".adjust_funds" do
    setup _context do
      {:ok, player} = Player.new("Frank") |> Player.buy_loan(1000, 0.1)
      %{player: player}
    end

    test "decreasing by more than availabled funds zeroes player funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 2000)
      assert test_player.funds == 0
    end

    test "decreasing by less than funds returns expected amount", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 500)
      assert test_player.funds == 500
    end

    test "increasing raises player funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :increase, 1000)
      assert test_player.funds == 2000
    end
  end

end
