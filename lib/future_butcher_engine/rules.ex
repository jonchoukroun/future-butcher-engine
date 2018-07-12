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

  def check(%Rules{state: :in_game} = rules, :end_game) do
    {:ok, %Rules{rules | state: :game_over}}
  end

  def check(%Rules{state: :in_game} = rules, :buy_cut) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :sell_cut) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :pay_debt) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game, turns_left: 0} = rules, :change_station) do
    {:game_over, %Rules{rules | state: :game_over}}
  end

  def check(%Rules{state: :in_game} = rules, :change_station) do
    rules = decrement_turn(rules)
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(_state, _action), do: {:error, :violates_current_rules}

  defp decrement_turn(rules) do
    rules |> Map.put(:turns_left, Map.get(rules, :turns_left) - 1)
  end

end
