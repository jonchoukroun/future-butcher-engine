defmodule FutureButcherEngine.Player do
  alias __MODULE__

  @enforce_keys [:name, :health, :cash, :debt]
  defstruct [:name, :health, :cash, :debt]

  @health_range 1..100

  def new(health, cash) when health in (@health_range) and cash > 0 do
    {:ok, %Player{name: nil, health: health, cash: cash, debt: cash}}
  end

  def new(_health, _cash) do
    {:error, :invalid_player_values}
  end

end