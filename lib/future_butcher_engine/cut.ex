defmodule FutureButcherEngine.Cut do
  alias __MODULE__

  @derive {Jason.Encoder, only: [:type, :price]}
  defstruct [:type, :price]

  @cut_values %{
    :brains => %{:max => 10,  :slope => -7500.0, :price_intercept => 100_000},
    :heart  => %{:max => 10,  :slope => -1000.0, :price_intercept => 25_000},
    :flank  => %{:max => 20,  :slope => -450.0,  :price_intercept => 14_000},
    :ribs   => %{:max => 40,  :slope => -83.0,   :price_intercept => 3500},
    :liver  => %{:max => 40,  :slope => -83.0,   :price_intercept => 3500}
  }

  @cuts_list Map.keys(@cut_values)

  def cut_names, do: @cuts_list

  def maximum_quantity(cut) when cut in @cuts_list, do: @cut_values[cut][:max]
  def maximum_quantity(_cut), do: {:error, :invalid_cut_name}

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

  defp calculate_price(:brains, 0), do: Enum.random(150_000..200_000)
  defp calculate_price(:heart, 0), do: Enum.random(50000..100000)
  defp calculate_price(:flank, 0), do: Enum.random(20000..40000)
  defp calculate_price(:ribs, 0), do: Enum.random(8000..18000)
  defp calculate_price(:liver, 0), do: Enum.random(8000..18000)
  defp calculate_price(_type, 0), do: nil

  defp calculate_price(type, quantity) do
    slope     = @cut_values[type][:slope]
    max_price = @cut_values[type][:price_intercept]
    round((slope * quantity) + max_price)
  end

  defp valid_quantity?(type, quantity), do: quantity <= @cut_values[type][:max]

end
