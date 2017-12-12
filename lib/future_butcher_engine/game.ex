defmodule FutureButcherEngine.Game do
  use GenServer
  alias FutureButcherEngine.{Game, Player, Station, Rules}

  @enforce_keys [:player, :rules]
  defstruct [:player, :rules]

  def start_link(turns, health, funds)
  when is_integer(turns)
  when is_integer(health)
  when is_integer(funds) do
    game_rules = %{turns: turns, health: health, funds: funds}
    GenServer.start_link(__MODULE__, game_rules, [])
  end

  def init(game_rules) do
    {:ok, %{
      rules: Rules.new(game_rules.turns),
      player: Player.new(game_rules.health, game_rules.funds),
      station: nil}}
  end

  def start_game(game) do
    GenServer.call(game, :start_game)
  end

  def visit_market(game) do
    GenServer.call(game, :visit_market)
  end

  def handle_call(:start_game, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :start_game)
    do
      state_data
      |> update_rules(rules)
      |> travel_to(:downtown)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
    end
  end

  def handle_call(:visit_market, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :visit_market)
    do
      state_data
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
    end
  end

  defp current_market(game), do: Map.get(state_data, :station).market

  defp update_rules(state_data, rules), do: %{state_data | rules: rules}

  defp travel_to(state_data, station) do
    %{state_data | station: Station.new(station)}
  end

  defp reply_success(state_data, reply), do: {:reply, reply, state_data}

end