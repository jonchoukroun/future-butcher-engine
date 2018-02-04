defmodule FutureButcherEngine.Game do
  use GenServer
  alias FutureButcherEngine.{Player, Station, Rules}

  @enforce_keys [:player, :rules]
  defstruct [:player, :rules]

  @stations [:downtown, :venice_beach, :koreatown, :culver_city, :silverlake]

  def start_link(player_name, turns, health, funds)
  when is_binary(player_name)
  when is_integer(turns)
  when is_integer(health)
  when is_integer(funds) do
    game_rules = %{
      player_name: player_name, turns: turns, health: health, funds: funds}

    GenServer.start_link(__MODULE__, game_rules, name: via_tuple(player_name))
  end

  def via_tuple(name), do: {:via, Registry, {Registry.Game, name}}

  # Client functions

  def init(game_rules) do
    {:ok, %{
      rules: Rules.new(game_rules.turns),
      player: Player.new(
        game_rules.player_name, game_rules.health, game_rules.funds),
      station: nil}}
  end

  def start_game(game) do
    GenServer.call(game, :start_game)
  end

  def visit_market(game) do
    GenServer.call(game, :visit_market)
  end

  def leave_market(game) do
    GenServer.call(game, :leave_market)
  end

  def buy_cut(game, cut, amount) when amount > 0 do
    GenServer.call(game, {:buy_cut, cut, amount})
  end

  def sell_cut(game, cut, amount) when amount > 0 do
    GenServer.call(game, {:sell_cut, cut, amount})
  end

  def visit_subway(game) do
    GenServer.call(game, :visit_subway)
  end

  def leave_subway(game) do
    GenServer.call(game, :leave_subway)
  end

  def change_station(game, destination) do
    GenServer.call(game, {:change_station, destination})
  end


  # GenServer callbacks

  def handle_call(:start_game, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :start_game)
    do
      state_data
      |> update_rules(rules)
      |> travel_to(:downtown)
      |> reply_success({:ok, :game_started})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call(:visit_market, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :visit_market)
    do
      state_data
      |> update_rules(rules)
      |> reply_success({:ok, :visiting_market})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call(:leave_market, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :leave_market)
    do
      state_data
      |> update_rules(rules)
      |> reply_success({:ok, :left_market})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call({:buy_cut, cut, amount}, _from, state_data) do
    with  {:ok, rules} <- Rules.check(state_data.rules, :buy_cut),
                 {:ok} <- valid_amount?(state_data.station.market, cut, amount),
           {:ok, cost} <- get_price(state_data.station.market, cut, amount),
         {:ok, player} <- Player.buy_cut(state_data.player, cut, amount, cost)
    do
      state_data
      |> update_market(cut, amount, :buy)
      |> update_player(player)
      |> update_rules(rules)
      |> reply_success(
        {:ok, String.to_atom("#{amount}_#{cut}_bought_for_#{cost}")})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call({:sell_cut, cut, amount}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :sell_cut),
                {:ok} <- cuts_owned?(state_data.player.pack, cut, amount),
        {:ok, profit} <- get_price(state_data.station.market, cut, amount),
        {:ok, player} <- Player.sell_cut(state_data.player, cut, amount, profit)
    do
      state_data
      |> update_market(cut, amount, :sell)
      |> update_player(player)
      |> update_rules(rules)
      |> reply_success(
        {:ok, String.to_atom("#{amount}_#{cut}_sold_for_#{profit}")})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call(:visit_subway, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :visit_subway)
    do
      state_data
      |> update_rules(rules)
      |> reply_success({:ok, :visit_subway})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call(:leave_subway, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :leave_subway)
    do
      state_data
      |> update_rules(rules)
      |> reply_success({:ok, :left_subway})
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end

  def handle_call({:change_station, destination}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :change_station),
                {:ok} <- valid_destination?(destination)
    do
      state_data
      |> update_rules(rules)
      |> travel_to(destination)
      |> reply_success(
        {:ok, String.to_atom("traveled_to_#{Atom.to_string(destination)}")})
    else
      {:game_over, rules} ->
        state_data |> update_rules(rules) |> end_game()
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end


  # Validations

  defp valid_amount?(market, cut, amount) do
    if Map.get(market, cut).quantity >= amount do
      {:ok}
    else
      {:error, :invalid_amount}
    end
  end

  defp valid_destination?(destination) when destination in @stations, do: {:ok}

  defp valid_destination?(_), do: {:error, :invalid_station}

  defp cuts_owned?(pack, cut, amount) do
    if Map.get(pack, cut) >= amount do
      {:ok}
    else
      {:error, :invalid_amount}
    end
  end


  # Computations

  defp get_price(market, cut, amount) do
    if Map.get(market, cut) do
      {:ok, Map.get(market, cut).price * amount}
    else
      {:error, :not_for_sale}
    end
  end

  defp access_cut_value(cut, k)
  when k in [:price, :quantity] do
    [Access.key(:station), Access.key(:market), Access.key(cut), Access.key(k)]
  end


  # Updates

  defp update_market(state_data, cut, amount, transaction_type) do
    amount = if (transaction_type == :buy), do: amount * -1, else: amount

    put_in(state_data, access_cut_value(cut, :quantity),
      Map.get(state_data.station.market, cut).quantity + amount)
  end

  defp update_player(state_data, player), do: %{state_data | player: player}

  defp update_rules(state_data, rules), do: %{state_data | rules: rules}

  defp travel_to(state_data, station) do
    %{state_data | station: Station.new(station)}
  end


  # Replies

  defp reply_success(state_data, reply), do: {:reply, reply, state_data}

  defp end_game(state_data), do: {:reply, :game_over, state_data}

end