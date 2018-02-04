defmodule FutureButcherEngine.Cut do
  alias __MODULE__

  defstruct [:type, :price]

  @cut_values %{
    :flank => %{:max => 20,  :slope => -450.0,  :max_price => 14_000},
    :heart => %{:max => 10,  :slope => -1000.0, :max_price => 25_000},
    :liver => %{:max => 100, :slope => -0.55,   :max_price => 65},
    :loin  => %{:max => 45,  :slope => -17.0,   :max_price => 1300},
    :ribs  => %{:max => 40,  :slope => -83.0,   :max_price => 3500}
  }

  @cuts_list Map.keys(@cut_values)

  def new(type, quantity) when type in @cuts_list do
    case valid_quantity?(type, quantity) do
      true ->
        {:ok, %Cut{type: type, price: calculate_price(type, quantity)}}
      false ->
        msg = "exceeds_#{type}_maximum"
        |> String.to_atom
        {:error, msg}
    end
  end

  def new(_type, _quantity), do: {:error, :invalid_cut_type}

  def new(_), do: {:error, :missing_inputs}

  defp calculate_price(type, quantity) do
    slope     = @cut_values[type][:slope]
    max_price = @cut_values[type][:max_price]
    round((slope * quantity) + max_price)
  end

  defp valid_quantity?(type, quantity), do: quantity <= @cut_values[type][:max]

end