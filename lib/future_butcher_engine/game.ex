defmodule FutureButcherEngine.Game do
  use GenServer, start: { __MODULE__, :start_link, [] }, restart: :transient
  alias FutureButcherEngine.{Player, Station, Rules}

  @enforce_keys [:player, :rules]
  defstruct [:player, :rules]

  @stations [:downtown, :venice_beach, :koreatown, :culver_city, :silverlake]

  # Hardcoded to allow game/player creation from player_name arg only
  @turns 10
  @health 100
  @funds 5000

  # Temporarily set to full day during dev
  @timeout 24 * 60 * 60 * 1000

  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def via_tuple(name), do: {:via, Registry, {Registry.Game, name}}

  def handle_info(:timeout, state_data) do
    {:stop, {:shutdown, :timeout}, state_data}
  end

  # Client functions

  def init(name) do
    send(self(), {:set_state, name})
    {:ok, fresh_state(name)}
  end

  defp fresh_state(name) do
    %{
      rules: Rules.new(@turns),
      player: Player.new(name, @health, @funds),
      station: nil
    }
  end

  def start_game(game) do
    GenServer.call(game, :start_game)
  end

  def buy_cut(game, cut, amount) when amount > 0 do
    GenServer.call(game, {:buy_cut, cut, amount})
  end

  def sell_cut(game, cut, amount) when amount > 0 do
    GenServer.call(game, {:sell_cut, cut, amount})
  end

  def pay_debt(game) do
    GenServer.call(game, :pay_debt)
  end

  def change_station(game, destination) do
    GenServer.call(game, {:change_station, destination})
  end


  # GenServer callbacks

  def handle_info({:set_state, name}, _state_data) do
    state_data = case :ets.lookup(:game_state, name) do
      [] -> fresh_state(name)
      [{_key, state}] -> state
    end
    :ets.insert(:game_state, {name, state_data})
    {:noreply, state_data, @timeout}
  end

  def terminate({:shutdown, :timeout}, state_data) do
    :ets.delete(:game_state, state_data.player.player_name)
    :ok
  end

  def terminate(_reason, _timeout), do: :ok

  def handle_call(:start_game, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :start_game)
    do
      state_data
      |> update_rules(rules)
      |> travel_to(:downtown)
      |> reply_success(:ok)
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
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
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
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call(:pay_debt, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :pay_debt),
        {:ok, player} <- Player.pay_debt(state_data.player)
    do
      state_data
      |> update_rules(rules)
      |> update_player(player)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:change_station, destination}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :change_station),
                {:ok} <- valid_destination?(
                          state_data.station.station_name, destination),
        {:ok, player} <- Player.accrue_debt(state_data.player)
    do
      state_data
      |> update_rules(rules)
      |> update_player(player)
      |> travel_to(destination)
      |> reply_success(:ok)
    else
      {:game_over, rules} ->
        state_data |> update_rules(rules) |> reply_success(:game_over)
      {:error, msg} -> reply_failure(state_data, msg)
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

  defp valid_destination?(destination, station_name)
  when destination === station_name do
    {:error, :already_at_station}
  end

  defp valid_destination?(destination, _) when destination in @stations,
    do: {:ok}

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

  defp reply_success(state_data, reply) do
    :ets.insert(:game_state, {state_data.player.player_name, state_data})

    reply = {reply, state_data}
    {:reply, reply, state_data, @timeout}
  end

  defp reply_failure(state_data, reply) do
    {:reply, reply, state_data, @timeout}
  end

end