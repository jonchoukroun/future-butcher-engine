defmodule FutureButcherEngine.Game do
  use GenServer, start: { __MODULE__, :start_link, [] }, restart: :transient
  alias FutureButcherEngine.{Player, Station, Rules}

  @enforce_keys [:player, :rules]
  defstruct [:player, :rules]

  @stations [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton]

  @mugging_responses [:funds, :cuts]

  @turns 25

  # Temporarily set to full day during dev
  @timeout 24 * 60 * 60 * 1000

  def start_link(name) when is_binary(name) do
    GenServer.start_link(__MODULE__, name, name: via_tuple(name))
  end

  def via_tuple(name), do: {:via, Registry, {Registry.Game, name}}


  # Client functions ===========================================================

  def init(name) do
    send(self(), {:set_state, name})
    {:ok, fresh_state(name)}
  end

  defp fresh_state(name) do
    %{
      rules: Rules.new(@turns),
      player: Player.new(name),
      station: nil
    }
  end

  def start_game(game) do
    GenServer.call(game, :start_game)
  end


  # Debt -----------------------------------------------------------------------

  def pay_debt(game) do
    GenServer.call(game, {:pay_debt})
  end


  # Buy/sell cuts --------------------------------------------------------------

  def buy_cut(game, cut, amount) when amount > 0 do
    GenServer.call(game, {:buy_cut, cut, amount})
  end

  def sell_cut(game, cut, amount) when amount > 0 do
    GenServer.call(game, {:sell_cut, cut, amount})
  end


  # Travel/transit -------------------------------------------------------------

  def change_station(game, destination) do
    GenServer.call(game, {:change_station, destination})
  end

  def fight_mugger(game) do
    GenServer.call(game, {:fight_mugger})
  end

  def pay_mugger(game, response) do
    GenServer.call(game, {:pay_mugger, response})
  end


  # Items ----------------------------------------------------------------------

  def buy_pack(game, pack) do
    GenServer.call(game, {:buy_pack, pack})
  end

  def buy_weapon(game, weapon) do
    GenServer.call(game, {:buy_weapon, weapon})
  end

  def replace_weapon(game, weapon) do
    GenServer.call(game, {:replace_weapon, weapon})
  end

  def drop_weapon(game) do
    GenServer.call(game, {:drop_weapon})
  end

  # GenServer callbacks ========================================================

  def handle_info(:timeout, state_data) do
    {:stop, {:shutdown, :timeout}, state_data}
  end

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
      |> update_rules(decrement_turn(rules, 1))
      |> travel_to(:downtown)
      |> reply_success(:ok)
    else
      {:error, msg} -> {:reply, {:error, msg}, state_data}
    end
  end


  # Debt/loans -----------------------------------------------------------------

  def handle_call({:pay_debt}, _from, state_data) do
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


  # Buy/sell cuts --------------------------------------------------------------

  def handle_call({:buy_cut, cut, amount}, _from, state_data) do
    with  {:ok, rules} <- Rules.check(state_data.rules, :buy_cut),
                 {:ok} <- valid_amount?(state_data.station.market, cut, amount),
           {:ok, cost} <- get_cut_price(state_data.station.market, cut, amount),
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
        {:ok, profit} <- get_cut_price(state_data.station.market, cut, amount),
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


  # Travel/transit -------------------------------------------------------------

  def handle_call({:change_station, destination}, _from, state_data) do
    with       {:ok} <- valid_destination?(state_data.station.station_name, destination),
      {:ok, outcome} <- Station.random_encounter(
                          state_data.player.pack_space, state_data.rules.turns_left, destination),
        {:ok, rules} <- Rules.check(state_data.rules, outcome),
       {:ok, player} <- Player.accrue_debt(state_data.player)
    do
      state_data
      |> update_rules(decrement_turn(rules, 1))
      |> update_player(player)
      |> travel_to(destination)
      |> reply_success(:ok)
    else
      {:game_over, rules} ->
        state_data |> update_rules(rules) |> reply_success(:game_over)
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:fight_mugger}, _from, state_data) do
    with           {:ok, rules} <- Rules.check(state_data.rules, :fight_mugger),
         {:ok, player, outcome} <- Player.fight_mugger(state_data.player),
           {:ok, turns_penalty} <- generate_turns_penalty(state_data.rules.turns_left, outcome)
    do
      state_data
      |> update_player(player)
      |> update_rules(decrement_turn(rules, turns_penalty))
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:pay_mugger, response}, _from, state_data) when response in @mugging_responses do
    with {:ok, rules}  <- Rules.check(state_data.rules, :pay_mugger),
         {:ok, player} <- Player.pay_mugger(state_data.player, response)
    do
      state_data
      |> update_player(player)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:pay_mugger, _response}, _from, _state_data), do: {:error, :invalid_response}


  # Packs ----------------------------------------------------------------------

  def handle_call({:buy_pack, pack}, _from, state_data) do
    with            {:ok, rules} <- Rules.check(state_data.rules, :buy_pack),
         {:ok, pack_space, cost} <- get_pack_details(state_data.station.store, pack),
                  {:ok, player} <- Player.buy_pack(state_data.player, pack_space, cost)
    do
      state_data
      |> update_rules(rules)
      |> update_player(player)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:buy_weapon, weapon}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :buy_weapon),
          {:ok, cost} <- get_weapon_price(state_data.station.store, weapon, :cost),
        {:ok, player} <- Player.buy_weapon(state_data.player, weapon, cost)
    do
      state_data
      |> update_rules(rules)
      |> update_player(player)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:replace_weapon, weapon}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :replace_weapon),
          {:ok, cost} <- get_weapon_price(state_data.station.store, weapon, :cost),
         {:ok, value} <-
           get_weapon_price(state_data.station.store, state_data.player.weapon, :value),
        {:ok, player} <- Player.replace_weapon(state_data.player, weapon, cost, value)
    do
      state_data
      |> update_rules(rules)
      |> update_player(player)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:drop_weapon}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :drop_weapon),
        {:ok, player} <- Player.drop_weapon(state_data.player)
    do
      state_data
      |> update_rules(rules)
      |> update_player(player)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end

  end

  # Validations ================================================================

  defp valid_amount?(market, cut, amount) do
    if Map.get(market, cut).quantity >= amount do
      {:ok}
    else
      {:error, :invalid_amount}
    end
  end

  defp valid_destination?(current_station, destination)
  when destination === current_station, do: {:error, :already_at_station}

  defp valid_destination?(_current_station, destination) when destination in @stations, do: {:ok}

  defp valid_destination?(_station_name, _destination), do: {:error, :invalid_station}

  defp cuts_owned?(pack, cut, amount) do
    if Map.get(pack, cut) >= amount do
      {:ok}
    else
      {:error, :invalid_amount}
    end
  end


  # Computations ===============================================================

  defp generate_turns_penalty(_turns_left, :victory), do: {:ok, 0}

  defp generate_turns_penalty(1, :defeat), do: {:ok, 1}

  defp generate_turns_penalty(turns_left, :defeat) do
    {:ok, Enum.random(1..Enum.min([turns_left, 4]))}
  end

  defp generate_turns_penalty(_turns_left, _outcome), do: {:error, :invalid_outcome}

  defp get_pack_details(store, pack) do
    if Map.get(store, pack) do
      {:ok, Map.get(store, pack).pack_space, Map.get(store, pack).price}
    else
      {:error, :not_for_sale}
    end
  end

  defp get_weapon_price(store, weapon, :cost) do
    if Map.get(store, weapon) do
      {:ok, Map.get(store, weapon).price}
    else
      {:error, :not_for_sale}
    end
  end

  defp get_weapon_price(store, weapon, :value) do
    item = Map.get(store, weapon)
    if item, do: {:ok, item.price}, else: {:ok, 0}
  end

  defp get_cut_price(market, cut, amount) do
    if Map.get(market, cut) do
      {:ok, Map.get(market, cut).price * amount}
    else
      {:error, :not_for_sale}
    end
  end

  defp access_cut_value(cut, k) when k in [:price, :quantity] do
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

  defp decrement_turn(rules, turns) do
    rules |> Map.put(:turns_left, Map.get(rules, :turns_left) - turns)
  end

  defp travel_to(state_data, station) do
    %{state_data | station: Station.new(station, state_data.rules.turns_left)}
  end


  # Replies ====================================================================

  defp reply_success(state_data, reply) do
    :ets.insert(:game_state, {state_data.player.player_name, state_data})

    reply = {reply, state_data}
    {:reply, reply, state_data, @timeout}
  end

  defp reply_failure(state_data, reply) do
    {:reply, reply, state_data, @timeout}
  end

end
