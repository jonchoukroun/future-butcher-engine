defmodule FutureButcherEngine.SharedExamples.FailedActions do

  defmacro __using__(_opts) do
    quote do
      # test "Prohibited actions return expected failure",
      # %{state: state, except: except} do
      #   rules = %Rules{Rules.new(10) | state: state}
      #   error = {:error, :violates_current_rules}

      #   [:start_game, :visit_market, :leave_market, :buy_cut, :sell_cut,
      #   :visit_subway, :leave_subway, :change_station, :end_game]
      #   |> Enum.reject(fn action -> Enum.member?(except, action) end)
      #   |> Enum.each(fn a -> assert Rules.check(rules, a == error) end)
      # end
    end
  end

  defmacro failed_actions(except) do
    quote do
      use ExUnit.Case

      assert unquote(except) == :initialized

    end
  end

end
