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

  def visit_market(game) do
    GenServer.call(game, :visit_market)
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

  def leave_market(game) do
    GenServer.call(game, :leave_market)
  end

  def handle_call(:leave_market, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :leave_market)
    do
      state_data
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
    end
  end

  def buy_cut(game, cut, amount) do
    GenServer.call(game, {:buy_cut, cut, amount})
  end

  def handle_call({:buy_cut, cut, amount}, _from, state_data) do
    with {:ok, rules}  <- Rules.check(state_data.rules, :buy_cut),
         {:ok, price}  <- get_price(state_data.station.market, cut, amount),
         {:ok, player} <- Player.buy_cut(state_data.player, cut, amount, price)
    do
      state_data
      |> update_market(cut, amount, :buy)
      # |> update_player(player)
      # |> update_rules(rules)
      |> reply_success(:ok)
    else
      :error -> {:reply, :error, state_data}
    end
  end

  defp get_price(market, cut, amount) do
    case valid_amount?(market, cut, amount) do
      {:ok} ->
        {:ok, Map.get(market, cut).price * amount}
      {:error, msg} ->
        {:error, msg}
    end
  end

  defp valid_amount?(market, cut, amount) do
    if Map.get(market, cut).quantity > amount do
      {:ok}
    else
      {:error, :invalid_amount}
    end
  end

  defp update_market(state_data, cut, amount, transaction_type) do
    amount = if (transaction_type == :buy), do: amount * -1, else: amount

    put_in(state_data, access_cut_value(cut, :quantity),
      Map.get(state_data.station.market, cut).quantity + amount)
  end

  defp access_cut_value(cut, k)
  when k in [:price, :quantity] do
    [Access.key(:station), Access.key(:market), Access.key(cut), Access.key(k)]
  end

  defp update_player(state_data, player), do: %{state_data | player: player}

  defp update_rules(state_data, rules), do: %{state_data | rules: rules}

  defp travel_to(state_data, station) do
    %{state_data | station: Station.new(station)}
  end

  defp reply_success(state_data, reply), do: {:reply, reply, state_data}

end