defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player


  # New player ----------------------------------------------------------------

  test "New players created with an empty pack, and no capital or weapon" do
    player = Player.new("Frank")
    assert player.player_name == "Frank"
    assert player.funds       == 5000
    assert player.debt        == 5000
    assert player.pack_space  == 20
    assert player.weapon      == nil

    player.pack
    |> Map.keys()
    |> Enum.each(fn (c) -> assert(Map.fetch!(player.pack, c) == 0) end)
  end


  # Packs ----------------------------------------------------------------------

  describe ".buy_pack" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with less space than current pack", context do
      assert Player.buy_pack(context.player, 19, 100) == {:error, :must_upgrade_pack}
    end

    test "with insufficient funds", context do
      assert Player.buy_pack(context.player, 25, 6000) == {:error, :insufficient_funds}
    end

    test "with more space", context do
      {:ok, test_player} = Player.buy_pack(context.player, 25, 500)
      assert test_player.pack_space == 25
      assert test_player.funds      == 4500
    end
  end


  # Debt/Loans -----------------------------------------------------------------

  describe ".accrue_debt" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with no debt does nothing", context do
      player = %Player{context.player | debt: 0}
      {:ok, test_player} = Player.accrue_debt(player)
      assert test_player === player
    end

    test "with debt raises debt by interest rate amount", context do
      {:ok, test_player} = Player.accrue_debt(context.player)
      assert test_player.debt === 5750
    end
  end

  describe ".pay_debt with debt greater than funds" do
    setup _context do
      %{player: %Player{Player.new("Frank") | funds: 0}}
    end

    test "should return error", context do
      assert Player.pay_debt(context.player) === {:error, :insufficient_funds}
    end
  end

  describe ".pay_debt with funds greater than debt" do
    setup _context do
      %{player: %Player{Player.new("Frank") | funds: 8000}}
    end

    test "should clear debt", context do
      {:ok, test_player} = Player.pay_debt(context.player)
      assert test_player.debt === 0
    end

    test "should reduce funds by amount of debt", context do
      {:ok, test_player} = Player.pay_debt(context.player)
      assert test_player.funds === 3000
    end
  end


  # Buy/Sell Cuts --------------------------------------------------------------

  describe ".buy_cut" do
    setup _context do
      %{player: Player.new("Frank")}
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
      player = Player.new("Frank")
      {:ok, player} = Player.buy_cut(player, :ribs, 5, 500)
      %{player: player}
    end

    test "with more cuts than owned", context do
      assert Player.sell_cut(context.player, :ribs, 6, 500) == {:error, :insufficient_cuts}
    end

    test "with valid args decreases cut and increases funds", context do
      {:ok, test_player} = Player.sell_cut(context.player, :ribs, 5, 1000)

      assert test_player.pack.ribs == 0
      assert test_player.funds     == 5500
    end
  end


  # Weapons --------------------------------------------------------------------

  describe ".buy_weapon with no current weapon" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with sufficient funds and pack space adds weapon and decreases funds", context do
      {:ok, test_player } = Player.buy_weapon(context.player, :machete, 1000)
      assert test_player.funds  == 4000
      assert test_player.weapon == :machete
    end

    test "with insufficient funds returns error", context do
      assert Player.buy_weapon(context.player, :machete, 8000) == {:error, :insufficient_funds}
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
      player = Player.new("Frank")
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
      {:ok, test_player} = Player.replace_weapon(context.player, :hedge_clippers, 5000, 1500)
      assert test_player.weapon == :hedge_clippers
      assert test_player.funds  == 500
    end
  end


  # Muggings -------------------------------------------------------------------

  describe ".fight_mugger" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with no weapon returns defeat", context do
      assert Player.fight_mugger(context.player) == {:ok, context.player, :defeat}
    end

    test "with a weapon returns defeat or victory", context do
      {:ok, test_player} = Player.buy_weapon(context.player, :machete, 0)
      case Player.fight_mugger(test_player) do
        {:ok, player, :defeat} ->
          assert player === test_player
        {:ok, player, :victory} ->
          starting_cuts = Enum.reduce(test_player.pack, 0, fn(cut, acc) -> acc + elem(cut, 1) end)
          test_cuts     = Enum.reduce(player.pack, 0, fn(cut, acc) -> acc + elem(cut, 1) end)

          assert test_cuts >= starting_cuts
      end
    end
  end

  describe ".pay_mugger :cuts" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with no cuts returns error", context do
      assert Player.pay_mugger(context.player, :cuts) == {:error, :no_cuts_owned}
    end

    test "with 1 cut type removes all cuts", context do
      {:ok, test_player} = Player.buy_cut(context.player, :heart, 3, 0)
      {:ok, test_player} = Player.pay_mugger(test_player, :cuts)
      assert test_player.pack.heart == 0
    end

    test "with multiple cut types owned removes all of 1 cut type", context do
      {:ok, player} = Player.buy_cut(context.player, :heart, 3, 0)
      {:ok, player} = Player.buy_cut(player, :loin, 2, 0)
      {:ok, player} = Player.buy_cut(player, :ribs, 1, 0)

      {:ok, test_player} = Player.pay_mugger(player, :cuts)
      assert Map.keys(test_player.pack)
              |> Enum.filter(fn cut -> test_player.pack[cut] > 0 end)
              |> Enum.count == 2
    end
  end

  describe ".pay_mugger :funds" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "with no funds returns error", context do
      test_player = %Player{context.player | funds: 0}
      assert Player.pay_mugger(test_player, :funds) == {:error, :insufficient_funds}
    end

    test "with funds decreases player's funds", context do
      {:ok, test_player} = Player.pay_mugger(context.player, :funds)
      assert context.player.funds > test_player.funds
    end

    test "does not decrease cuts", context do
      {:ok, test_player} = Player.pay_mugger(context.player, :funds)
      assert test_player.pack === context.player.pack
    end
  end

  describe ".pay_mugger :fish" do
    test "with invalid payoff type" do
      assert Player.pay_mugger(Player.new("Frank"), :fish) == {:error, :invalid_mugging_response}
    end
  end


  # Funds ----------------------------------------------------------------------

  describe ".adjust_funds" do
    setup _context do
      %{player: Player.new("Frank")}
    end

    test "decreasing by more than availabled funds zeroes player funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 6000)
      assert test_player.funds == 0
    end

    test "decreasing by less than funds returns expected amount", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 500)
      assert test_player.funds == 4500
    end

    test "increasing raises player funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :increase, 1000)
      assert test_player.funds == 6000
    end
  end

end
