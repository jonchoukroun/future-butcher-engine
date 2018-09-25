defmodule FutureButcherEngine.Pack do

  @packs %{
    :mini_fridge   => %{:pack_space => 60},
    :shopping_cart => %{:pack_space => 50},
    :wheelbarrow   => %{:pack_space => 40},
    :suitcase      => %{:pack_space => 30}
  }

  @packs_list Map.keys(@packs)

  def pack_types, do: @packs_list

  def get_pack_space(pack) when pack in @packs_list, do: Map.get(@packs, pack).pack_space
  def get_pack_space(_pack), do: {:error, :invalid_pack_type}

  def generate_price(pack, turns_left) when pack in @packs_list do
    get_pack_space(pack)
    |> Kernel./(turns_left)
    |> Kernel.*(1000)
    |> round()
  end
  def generate_price(_pack, _turns_left), do: {:error, :invalid_pack_type}

end
