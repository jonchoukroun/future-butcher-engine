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
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :end_game) do
    {:ok, %Rules{rules | state: :game_over}}
  end

  def check(%Rules{state: :in_game} = rules, :buy_loan) do
    {:ok, %Rules{rules | state: :in_game}}
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

  def check(%Rules{state: :in_game, turns_left: 0} = rules, :mugging) do
    {:game_over, %Rules{rules | state: :game_over}}
  end

  def check(%Rules{state: :in_game, turns_left: 0} = rules, :end_transit) do
    {:game_over, %Rules{rules | state: :game_over}}
  end

  def check(%Rules{state: :in_game} = rules, :end_transit) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :mugging) do
    {:ok, %Rules{rules | state: :mugging}}
  end

  def check(%Rules{state: :mugging, turns_left: turns_left} = rules, :fight_mugger)
  when turns_left > 0 do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :mugging} = rules, :pay_mugger) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :buy_pack) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :buy_weapon) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :replace_weapon) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(%Rules{state: :in_game} = rules, :drop_weapon) do
    {:ok, %Rules{rules | state: :in_game}}
  end

  def check(_state, _action), do: {:error, :violates_current_rules}

end
