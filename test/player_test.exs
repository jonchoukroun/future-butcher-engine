defmodule FutureButcherEngine.PlayerTest do
  use ExUnit.Case
  alias FutureButcherEngine.Player


  # New player ----------------------------------------------------------------

  test "New players created with an empty pack, and no capital or weapon" do
    player = Player.new("Frank")
    assert player.player_name == "Frank"
    assert player.cash       == 5000
    assert player.debt        == 5000
    assert player.pack_space  == 20
    assert player.weapon      == nil

    player.pack
    |> Map.keys()
    |> Enum.each(fn (c) -> assert(Map.fetch!(player.pack, c) == 0) end)
  end


  # Health ---------------------------------------------------------------------

  describe ".decrease_health" do
    setup [:initialize_player]

    test "with missing damage amount", context do
      assert Player.decrease_health(context.player) === {:error, :missing_damage_amount}
    end

    test "with damage amount = 0", context do
      {:ok, player} = Player.decrease_health(context.player, 0)
      assert player.health === 100
    end

    test "with damage less than health", context do
      damage = 50
      {:ok, %Player{health: health}} = Player.decrease_health(context.player, damage)
      assert health === context.player.health - damage
    end

    test "with damage greater than health", context do
      damage = 150
      {:ok, %Player{health: health}} = Player.decrease_health(context.player, damage)
      assert health === context.player.health - damage
    end
  end

  # Packs ----------------------------------------------------------------------

  describe ".buy_pack" do
    setup [:initialize_player]

    test "with less space than current pack", context do
      assert Player.buy_pack(context.player, 19, 100) == {:error, :must_upgrade_pack}
    end

    test "with insufficient cash", context do
      assert Player.buy_pack(context.player, 25, 6000) == {:error, :insufficient_cash}
    end

    test "with more space", context do
      {:ok, test_player} = Player.buy_pack(context.player, 25, 500)
      assert test_player.pack_space == 25
      assert test_player.cash      == 4500
    end
  end


  # Debt/Loans -----------------------------------------------------------------

  describe ".accrue_debt" do
    setup [:initialize_player]

    test "with no debt does nothing", context do
      player = %Player{context.player | debt: 0}
      {:ok, test_player} = Player.accrue_debt(player, 1)
      assert test_player === player
    end

    test "with debt raises debt by interest rate amount", context do
      expected_debt = context.player.debt * 1.05 |> round()
      {:ok, test_player} = Player.accrue_debt(context.player, 1)
      assert test_player.debt === expected_debt
    end

    test "with multiple turns accrues debt concurrently", context do
      turns = 5
      expected_debt = context.player.debt * :math.pow(1.05, turns) |> round()
      {:ok, test_player} = Player.accrue_debt(context.player, turns)
      assert test_player.debt === expected_debt
    end
  end

  describe ".pay_debt with debt greater than cash" do
    setup [:initialize_player, :zero_cash]

    test "should return error", context do
      assert Player.pay_debt(context.player) === {:error, :insufficient_cash}
    end
  end

  describe ".pay_debt with cash greater than debt" do
    setup [:initialize_player, :increase_cash]

    test "should clear debt", context do
      {:ok, test_player} = Player.pay_debt(context.player)
      assert test_player.debt === 0
    end

    test "should reduce cash by amount of debt", context do
      {:ok, test_player} = Player.pay_debt(context.player)
      assert test_player.cash === 3000
    end
  end


  # Buy/Sell Cuts --------------------------------------------------------------

  describe ".buy_cut" do
    setup [:initialize_player]

    test "with insufficient cash returns error", context do
      assert Player.buy_cut(context.player, :brains, 4, 10_000) == {:error, :insufficient_cash}
    end

    test "with insufficient space returns error", context do
      assert Player.buy_cut(context.player, :ribs, 100, 3000) == {:error, :insufficient_pack_space}
    end

    test "with valid args increases cuts and decreases cash", context do
      {:ok, test_player} = Player.buy_cut(context.player, :heart, 10, 1000)
      assert test_player.pack.heart == 10
      assert test_player.cash      == 4000
    end
  end

  describe ".sell_cut" do
    setup [:initialize_player, :buy_cut]

    test "with more cuts than owned", context do
      assert Player.sell_cut(context.player, :ribs, 6, 500) == {:error, :insufficient_cuts}
    end

    test "with valid args decreases cut and increases cash", context do
      {:ok, test_player} = Player.sell_cut(context.player, :ribs, 5, 1000)

      assert test_player.pack.ribs == 0
      assert test_player.cash     == 5500
    end
  end


  # Weapons --------------------------------------------------------------------

  describe ".buy_weapon with no current weapon" do
    setup [:initialize_player]

    test "with sufficient cash should add weapon and decrease cash", context do
      {:ok, test_player } = Player.buy_weapon(context.player, :machete, 1000)
      assert test_player.cash  == 4000
      assert test_player.weapon == :machete
    end

    test "with insufficient cash should return error", context do
      assert Player.buy_weapon(context.player, :machete, 8000) == {:error, :insufficient_cash}
    end

    test "with invalid weapon type should return error", context do
      assert Player.buy_weapon(context.player, :cat, 100) == {:error, :invalid_weapon_type}
    end
  end

  describe ".buy_weapon with existing weapon" do
    setup [:initialize_player, :buy_weapon]

    test "should return error", context do
      %{weapon: current_weapon} = context.player;
      assert Player.buy_weapon(context.player, current_weapon, 0) === {:error, :already_owns_weapon}
    end
  end

  describe ".replace_weapon with no existing weapon" do
    setup [:initialize_player]

    test "should return error", context do
      assert Player.replace_weapon(context.player, :machete, 0, 0) === {:error, :no_weapon_owned}
    end
  end

  describe ".replace_weapon with existing weapon" do
    setup [:initialize_player, :buy_weapon]

    test "with insufficient cash + trade-in value should return error", context do
      assert Player.replace_weapon(context.player, :buy_better_weapon, 6000, 100) ===
        {:error, :insufficient_cash}
    end

    test "with same weapon as current weapon should return error", context do
      %{weapon: current_weapon} = context.player
      assert Player.replace_weapon(context.player, current_weapon, 0, 0) ===
        {:error, :same_weapon_type}
    end

    test "with cheaper weapon should replace weapon and adjust cash", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :box_cutter, 500, 200)
      assert test_player.weapon === :box_cutter
      assert test_player.cash  === 4700
    end

    test "with valid args should replace weapon and adjust cash", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :power_claw, 1000, 200)
      assert test_player.weapon === :power_claw
      assert test_player.cash  === 4200
    end

    test "with insufficient cash, enough value should replace weapon and adjust cash", context do
      {:ok, test_player} = Player.replace_weapon(context.player, :katana, 5000, 1500)
      assert test_player.weapon === :katana
      assert test_player.cash  === 1500
    end
  end


  # Adrenal Gland Essential Oil ------------------------------------------------

  describe ".buy_oil" do
    setup [:initialize_player]

    test "returns error when already holding oil", context do
      player = Map.replace(context.player, :has_oil, true)
      assert Player.buy_oil(player) === {:error, :already_has_oil}
    end

    test "returns error when cash is too low", context do
      player = Map.replace(context.player, :cash, 19_999)
      assert Player.buy_oil(player) === {:error, :insufficient_cash}
    end

    test "updates player", context do
      player = Map.replace(context.player, :cash, 30_000)
      {:ok, %Player{cash: cash, has_oil: has_oil}} = Player.buy_oil(player)
      assert has_oil === true
      assert cash === 10_000
    end
  end

  describe ".use_oil" do
    setup [:initialize_player]

    test "returns player when not holding oil", context do
      assert Player.use_oil(context.player) === {:ok, context.player}
    end

    test "returns player when holding oil", context do
      player = Map.replace(context.player, :has_oil, true)
      assert Player.use_oil(player) === {:ok, %Player{player | has_oil: false}}
    end
  end


  # Muggings -------------------------------------------------------------------

  describe ".fight_mugger with essential oil and no weapon" do
    setup [:initialize_player, :add_oil]

    test "should return victory and deplete oil", context do
      assert Player.fight_mugger(context.player) === {
        :ok,
        %Player{context.player | has_oil: false},
        :victory
      }
    end
  end

  describe ".fight_mugger with no weapon" do
    setup [:initialize_player]

    test "should return victory on rand values 8 and higher, or defeat", context do
      # Will result in Enum.random(1..9) to return 9 then 1
      :rand.seed(:exsplus, {1, 2, 2})
      outcomes = for _ <- 1..2 do
        {:ok, _, outcome} = Player.fight_mugger(context.player)
        outcome
      end
      assert outcomes === [:victory, :defeat]
    end

    test "should decrease health on defeat", context do
      # Will result in Enum.random(1..9) to return 7
      :rand.seed(:exsplus, {1, 2, 1})
      {:ok, %Player{health: health}, _} = Player.fight_mugger(context.player)
      assert health <= 100
    end

    test "should return same health on victory", context do
      # Will result in Enum.random(1..9) to return 9
      :rand.seed(:exsplus, {1, 2, 2})
      {:ok, %Player{health: health}, _} = Player.fight_mugger(context.player)
      assert health === 100
    end
  end

  describe ".fight_mugger" do
    setup [:initialize_player, :buy_weapon]

    test "should return defeat or victory", context do
      fight_outcomes = [:defeat, :victory]

      {:ok, _player, test_outcome} = Player.fight_mugger(context.player)
      assert Enum.member?(fight_outcomes, test_outcome)
    end

    test "should decrease health", context do
      {:ok, player, _} = Player.fight_mugger(context.player)
      assert player.health <= 100
    end
  end

  describe ".bribe_mugger with sufficient cash" do
    setup [:initialize_player]

    test "should reduce cash by at least 20 but no more than 60%", context do
      {:ok, test_player} = Player.bribe_mugger(context.player)
      assert test_player.cash < context.player.cash

      loss = context.player.cash - test_player.cash
      assert loss / context.player.cash <= 0.3
      assert loss / context.player.cash >= 0.1
    end
  end

  describe ".bribe_mugger with insufficient cash and single cut type owned" do
    setup [:initialize_player, :buy_cut, :zero_cash]

    test "should zero out owned cuts", context do
      {:ok, test_player} = Player.bribe_mugger(context.player)
      assert get_pack_sum(test_player.pack) === 0
    end
  end

  describe ".bribe_mugger with insufficient cash and 2 cut types owned" do
    setup [:initialize_player, :buy_cut, :add_other_cuts, :zero_cash]

    test "should zero out only 1 cut type", context do
      base_cuts_owned = get_pack_sum(context.player.pack)

      {:ok, test_player} = Player.bribe_mugger(context.player)
      test_cuts_owned = get_pack_sum(test_player.pack)

      assert test_cuts_owned !== 0
      assert test_cuts_owned < base_cuts_owned
    end
  end

  describe ".bribe_mugger with insufficient cash and no cuts" do
    setup [:initialize_player, :zero_cash]

    test "should return error", context do
      assert Player.bribe_mugger(context.player) === {:error, :cannot_bribe_mugger}
    end
  end

  describe ".harvest_mugger without a weapon" do
    setup [:initialize_player, :buy_cut]

    test "should return current pack", context do
      assert context.player.pack === Player.harvest_mugger(context.player)
    end
  end

  describe ".harvest_mugger with no pack space" do
    setup [
      :initialize_player,
      :buy_weapon,
      :add_other_cuts,
      :add_other_cuts,
      :add_other_cuts,
      :add_other_cuts
    ]

    test "should not update pack", context do
      assert Player.harvest_mugger(context.player) === context.player.pack
    end
  end

  describe ".harvest_mugger" do
    setup [:initialize_player, :buy_weapon]

    test "should increase weight carried", context do
      player = Map.replace(context.player, :pack, Player.harvest_mugger(context.player))
      assert player.pack === %{brains: 1, heart: 1, flank: 2, liver: 1, ribs: 5}

      player = Map.replace(player, :pack, Player.harvest_mugger(player))
      assert player.pack === %{brains: 2, heart: 2, flank: 4, liver: 2, ribs: 10}

      player = Map.replace(player, :pack, Player.harvest_mugger(player))
      assert player.pack === %{brains: 2, heart: 2, flank: 4, liver: 2, ribs: 10}
    end
  end


  # cash ----------------------------------------------------------------------

  describe ".adjust_cash" do
    setup [:initialize_player]

    test "when decreasing by more than availabled cash should zero player cash", context do
      {:ok, test_player} = Player.adjust_cash(context.player, :decrease, 6000)
      assert test_player.cash == 0
    end

    test "when decreasing by less than cash should return expected amount", context do
      {:ok, test_player} = Player.adjust_cash(context.player, :decrease, 500)
      assert test_player.cash == 4500
    end

    test "when increasing should raise player cash", context do
      {:ok, test_player} = Player.adjust_cash(context.player, :increase, 1000)
      assert test_player.cash == 6000
    end
  end


  # Named setups ===============================================================

  defp initialize_player(_context) do
    %{player: Player.new "Frank"}
  end

  defp zero_cash(context) do
    %{player: %Player{context.player | cash: 0}}
  end

  defp increase_cash(context) do
    %{player: %Player{context.player | cash: 8000}}
  end

  defp buy_cut(context) do
    {:ok, player} = Player.buy_cut(context.player, :ribs, 5, 500)
    %{player: player}
  end

  defp add_other_cuts(context) do
    {:ok, player} = Player.buy_cut(context.player, :heart, 5, 0)
    %{player: player}
  end

  defp buy_weapon(context) do
    {:ok, player} = Player.buy_weapon(context.player, :hedge_clippers, 0)
    %{player: player}
  end

  defp add_oil(context) do
    %{player: %Player{context.player | has_oil: true}}
  end


  # Utilities ==================================================================

  defp get_pack_sum(pack) do
    Map.values(pack) |> Enum.reduce(0, fn(sum, n) -> sum + n end)
  end

end
