defmodule FutureButcherEngine.Rules do
  alias __MODULE__

  defstruct state: :initialized

  def new, do: %Rules{}

  def check(%Rules{state: :initialized} = rules, :start_game) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(_state, _action), do: :error
end