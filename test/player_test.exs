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
    setup [:initialize_player]

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
    setup [:initialize_player]

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
    setup [:initialize_player, :zero_funds]

    test "should return error", context do
      assert Player.pay_debt(context.player) === {:error, :insufficient_funds}
    end
  end

  describe ".pay_debt with funds greater than debt" do
    setup [:initialize_player, :increase_funds]

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
    setup [:initialize_player]

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
    setup [:initialize_player, :buy_cut]

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
    setup [:initialize_player]

    test "with sufficient funds should add weapon and decrease funds", context do
      {:ok, test_player } = Player.buy_weapon(context.player, :machete, 1000)
      assert test_player.funds  == 4000
      assert test_player.weapon == :machete
    end

    test "with insufficient funds should return error", context do
      assert Player.buy_weapon(context.player, :machete, 8000) == {:error, :insufficient_funds}
    end

    test "with invalid weapon type should return error", context do
      assert Player.buy_weapon(context.player, :cat, 100) == {:error, :invalid_weapon_type}
    end
  end

  describe ".buy_weapon with existing weapon" do
    setup [:initialize_player, :buy_weapon]

    test "should return error", context do
      assert Player.buy_weapon(context.player, :box_cutter, 0) == {:error, :already_owns_weapon}
    end
  end

  describe ".replace_weapon with no existing weapon" do
    setup [:initialize_player]

    test "should return error", context do
      assert Player.replace_weapon(context.player, :machete, 0, 0) == {:error, :no_weapon_owned}
    end
  end

  describe ".replace_weapon with existing weapon" do
    setup [:initialize_player, :buy_weapon]

    test "with insufficient funds + trade-in value should return error", context do
      assert Player.replace_weapon(context.player, :hedge_clippers, 6000, 100) ==
        {:error, :insufficient_funds}
    end

    test "with same weapon as current weapon should return error", context do
      assert Player.replace_weapon(context.player, :box_cutter, 0, 0) ==
        {:error, :same_weapon_type}
    end

    test "with cheaper weapon should replace weapon and adjust funds", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :brass_knuckles, 500, 200)
      assert test_player.weapon == :brass_knuckles
      assert test_player.funds  == 4700
    end

    test "with valid args should replace weapon and adjust funds", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :machete, 1000, 200)
      assert test_player.weapon == :machete
      assert test_player.funds  == 4200
    end

    test "with insufficient funds, enough value should replace weapon and adjust funds", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :hedge_clippers, 5000, 1500)
      assert test_player.weapon == :hedge_clippers
      assert test_player.funds  == 1500
    end
  end


  # Muggings -------------------------------------------------------------------

  describe ".fight_mugger with no weapon" do
    setup [:initialize_player]

    test "should return defeat", context do
      assert Player.fight_mugger(context.player) === {:ok, context.player, :defeat}
    end
  end

  describe ".fight_mugger" do
    setup [:initialize_player, :buy_weapon]

    test "should return defeat or victory", context do
      fight_outcomes = [:defeat, :victory]

      {:ok, _player, test_outcome} = Player.fight_mugger(context.player)
      assert Enum.member?(fight_outcomes, test_outcome)
    end
  end


  # describe ".pay_mugger :cuts" do
  #   setup _context do
  #     %{player: Player.new("Frank")}
  #   end
  #
  #   test "with no cuts returns error", context do
  #     assert Player.pay_mugger(context.player, :cuts) == {:error, :no_cuts_owned}
  #   end
  #
  #   test "with 1 cut type removes all cuts", context do
  #     {:ok, test_player} = Player.buy_cut(context.player, :heart, 3, 0)
  #     {:ok, test_player} = Player.pay_mugger(test_player, :cuts)
  #     assert test_player.pack.heart == 0
  #   end
  #
  #   test "with multiple cut types owned removes all of 1 cut type", context do
  #     {:ok, player} = Player.buy_cut(context.player, :heart, 3, 0)
  #     {:ok, player} = Player.buy_cut(player, :loin, 2, 0)
  #     {:ok, player} = Player.buy_cut(player, :ribs, 1, 0)
  #
  #     {:ok, test_player} = Player.pay_mugger(player, :cuts)
  #     assert Map.keys(test_player.pack)
  #             |> Enum.filter(fn cut -> test_player.pack[cut] > 0 end)
  #             |> Enum.count == 2
  #   end
  # end
  #
  # describe ".pay_mugger :funds" do
  #   setup _context do
  #     %{player: Player.new("Frank")}
  #   end
  #
  #   test "with no funds returns error", context do
  #     test_player = %Player{context.player | funds: 0}
  #     assert Player.pay_mugger(test_player, :funds) == {:error, :insufficient_funds}
  #   end
  #
  #   test "with funds decreases player's funds", context do
  #     {:ok, test_player} = Player.pay_mugger(context.player, :funds)
  #     assert context.player.funds > test_player.funds
  #   end
  #
  #   test "does not decrease cuts", context do
  #     {:ok, test_player} = Player.pay_mugger(context.player, :funds)
  #     assert test_player.pack === context.player.pack
  #   end
  # end
  #
  # describe ".pay_mugger :fish" do
  #   test "with invalid payoff type" do
  #     assert Player.pay_mugger(Player.new("Frank"), :fish) == {:error, :invalid_mugging_response}
  #   end
  # end


  # Funds ----------------------------------------------------------------------

  describe ".adjust_funds" do
    setup [:initialize_player]

    test "when decreasing by more than availabled funds should zero player funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 6000)
      assert test_player.funds == 0
    end

    test "when decreasing by less than funds should return expected amount", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :decrease, 500)
      assert test_player.funds == 4500
    end

    test "when increasing should raise player funds", context do
      {:ok, test_player} = Player.adjust_funds(context.player, :increase, 1000)
      assert test_player.funds == 6000
    end
  end


  # Named setups ===============================================================

  defp initialize_player(_context) do
    %{player: Player.new "Frank"}
  end

  defp zero_funds(context) do
    %{player: %Player{context.player | funds: 0}}
  end

  defp increase_funds(context) do
    %{player: %Player{context.player | funds: 8000}}
  end

  defp buy_cut(context) do
    {:ok, player} = Player.buy_cut(context.player, :ribs, 5, 500)
    %{player: player}
  end

  defp buy_weapon(context) do
    {:ok, player} = Player.buy_weapon(context.player, :box_cutter, 0)
    %{player: player}
  end

end
