defmodule FutureButcherEngine.Rules do
  alias __MODULE__

  @enforce_keys [:turns_left, :state]
  defstruct [:turns_left, :state]

  def new(turns) when is_integer(turns) and turns > 0 do
    %Rules{turns_left: turns, state: :initialized}
  end

  def new(_) do
    {:error, :invalid_turns}
  end

  def check(%Rules{state: :game_over}, _action) do
    {:error, :game_over}
  end

  def check(%Rules{state: :initialized} = rules, :start_game) do
    rules = decrement_turn(rules)
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :visit_market) do
    {:ok, %Rules{rules | state: :at_market}}
  end

  def check(%Rules{state: :in_game} = rules, :visit_subway) do
    {:ok, %Rules{rules | state: :at_subway}}
  end

  def check(%Rules{state: :in_game} = rules, :visit_loanshark) do
    {:ok, %Rules{rules | state: :at_loanshark}}
  end

  def check(%Rules{state: :in_game} = rules, :end_game) do
    {:ok, %Rules{rules | state: :game_over}}
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

  def check(%Rules{state: :at_subway} = rules, :leave_subway) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :at_loanshark} = rules, :repay_debt) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :at_subway, turns_left: 0} = rules,
    :change_station) do
    {:ok, %Rules{rules | state: :game_over}}
  end

  def check(%Rules{state: :at_subway} = rules, :change_station) do
    rules = decrement_turn(rules)
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(_state, _action), do: {:error, :violates_current_rules}

  defp decrement_turn(rules) do
    rules |> Map.put(:turns_left, Map.get(rules, :turns_left) - 1)
  end

end