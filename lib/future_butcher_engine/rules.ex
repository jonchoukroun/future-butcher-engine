defmodule FutureButcherEngine.Rules do
  alias __MODULE__

  defstruct state: :initialized

  def new, do: %Rules{}

  def check(%Rules{state: :initialized} = rules, :start_game) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :visit_market) do
    {:ok, %Rules{rules | state: :at_market}}
  end

  def check(%Rules{state: :in_game} = rules, :visit_subway) do
    {:ok, %Rules{rules | state: :at_subway}}
  end

  def check(%Rules{state: :in_game} = rules, :end_game) do
    {:ok, %Rules{rules | state: :game_end}}
  end

  def check(%Rules{state: :at_market} = rules, :buy_cut) do
    {:ok, %Rules{rules | state: :at_market}}
  end

  def check(%Rules{state: :at_market} = rules, :sell_cut) do
    {:ok, %Rules{rules | state: :at_market}}
  end

  def check(%Rules{state: :at_market} = rules, :leave_market) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :at_subway} = rules, :change_station) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :at_subway} = rules, :leave_subway) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(_state, _action), do: :error
end