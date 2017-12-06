defmodule CutTest do
  use ExUnit.Case
  alias FutureButcherEngine.Cut

  test  "Cut.new/2 with valid type and quantity creates struct" do
    assert Cut.new(:flank, 10) == {:ok, %Cut{type: :flank, price: 9500}}
  end

  test "Cut.new/2 with excessive quantity returns error" do
    assert Cut.new(:flank, 100) == {:error, :exceeds_flank_maximum}
  end

  # test "Cute.new/2 with invalid cut type returns error" do
  #   assert Cut.new(:blarg, 40) == {:error, :invalid_cut_type}
  # end
end