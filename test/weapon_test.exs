defmodule WeaponTest do
  use ExUnit.Case
  alias FutureButcherEngine.{Station, Weapon}

  describe ".generate_price" do
    test "on turns prior to 9am" do
      for t <- (24..21) do
        assert nil === Weapon.generate_price(:machete, t)
      end
    end

    test "katana on first available turn" do
      assert 60_000 === Weapon.generate_price(
        :katana, Station.store_open()
      )
    end

    test "katana on last available turn" do
      assert 640_000 === Weapon.generate_price(
        :katana, Station.store_close()
      )
    end

    test "machete on first available turn" do
      assert 30_000 === Weapon.generate_price(
        :machete, Station.store_open()
      )
    end

    test "machete on last available turn" do
      assert 320_000 === Weapon.generate_price(
        :machete, Station.store_close()
      )
    end

    test "power_claw on first available turn" do
      assert 18_000 === Weapon.generate_price(
        :power_claw, Station.store_open()
      )
    end

    test "power_claw on last available turn" do
      assert 190_000 === Weapon.generate_price(
        :power_claw, Station.store_close()
      )
    end

    test "hedge_clippers on first available turn" do
      assert 12_000 === Weapon.generate_price(
        :hedge_clippers, Station.store_open()
      )
    end

    test "hedge_clippers on last available turn" do
      assert 90_000 === Weapon.generate_price(
        :hedge_clippers, Station.store_close()
      )
    end

    test "box_cutter on first available turn" do
      assert 6_000 === Weapon.generate_price(
        :box_cutter, Station.store_open()
      )
    end

    test "box_cutter on last available turn" do
      assert 40_000 === Weapon.generate_price(
        :box_cutter, Station.store_close()
      )
    end
  end
end
