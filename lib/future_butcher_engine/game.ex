defmodule FutureButcherEngine.Game do
  use GenServer, start: { __MODULE__, :start_link, [] }, restart: :transient
  alias FutureButcherEngine.{Player, Station, Rules}

  @enforce_keys [:player, :rules]
  @derive {Jason.Encoder, only: [:player, :rules]}
  defstruct [:player, :rules]

  @stations [:beverly_hills, :downtown, :venice_beach, :hollywood, :compton, :bell_gardens]

  @turns 24

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

  def bribe_mugger(game) do
    GenServer.call(game, {:bribe_mugger})
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
      |> update_rules(rules)
      |> travel_to(:compton)
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
    with {:ok} <- valid_destination?(
        state_data.station.station_name, state_data.rules.turns_left, destination),
      {:ok, outcome} <- Station.random_encounter(
        state_data.player.pack_space,
        state_data.rules.turns_left - Station.get_travel_time(destination),
        destination),
      {:ok, rules} <- Rules.check(state_data.rules, outcome),
      {:ok, player} <- Player.accrue_debt(state_data.player, Station.get_travel_time(destination))
    do
      state_data
      |> update_rules(decrement_turns(rules, Station.get_travel_time(destination)))
      |> update_player(player)
      |> travel_to(destination)
      |> reply_success(:ok)
    else
      {:game_over, rules} ->
        state_data |> update_rules(rules) |> reply_success(:game_over)
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  # Handles running from mugger option when player has no weapon
  def handle_call({:fight_mugger}, _from, state_data) do
    with        {:ok, rules} <- Rules.check(state_data.rules, :fight_mugger),
      {:ok, player, outcome} <- Player.fight_mugger(state_data.player),
        {:ok, turns_penalty} <- generate_turns_penalty(outcome),
               {:ok, penalized_player} <- penalize_assets(player, outcome),
               {:ok, final_player} <- Player.accrue_debt(penalized_player, turns_penalty)
    do
      if outcome == :death do
        state_data
        |> update_player(player)
        |> update_rules(%Rules{turns_left: 0, state: :game_over})
        |> reply_success(:game_over)
      else
        state_data
        |> update_player(final_player)
        |> update_rules(decrement_turns(rules, turns_penalty))
        |> reply_success(:ok)
      end
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:bribe_mugger}, _from, state_data) do
    with {:ok, rules} <- Rules.check(state_data.rules, :bribe_mugger),
        {:ok, player} <- Player.bribe_mugger(state_data.player)
    do
      state_data
      |> update_player(player)
      |> update_rules(rules)
      |> reply_success(:ok)
    else
      {:error, msg} -> reply_failure(state_data, msg)
    end
  end

  def handle_call({:bribe_mugger, _response}, _from, _state_data), do: {:error, :invalid_response}


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

  defp valid_destination?(current_station, _turns_left, destination)
  when destination === current_station, do: {:error, :already_at_station}

  defp valid_destination?(_current_station, turns_left, :bell_gardens)
  when turns_left > 20, do: {:error, :station_not_open}

  defp valid_destination?(_current_station, turns_left, destination)
  when destination in @stations do
    case Station.get_travel_time(destination) > turns_left do
      true  -> {:error, :insufficient_turns}
      false -> {:ok}
    end
  end

  defp valid_destination?(_station_name, _turns_left, _destination), do: {:error, :invalid_station}

  defp cuts_owned?(pack, cut, amount) do
    if Map.get(pack, cut) >= amount do
      {:ok}
    else
      {:error, :invalid_amount}
    end
  end


  # Computations ===============================================================

  defp generate_turns_penalty(:death), do: {:ok, 0}
  defp generate_turns_penalty(:victory), do: {:ok, 0}
  defp generate_turns_penalty(:defeat), do: {:ok, 1}

  defp penalize_assets(player ,:death), do: {:ok, player}
  defp penalize_assets(player, :victory), do: {:ok, player}
  defp penalize_assets(player, :defeat), do: Player.bribe_mugger(player)

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

  defp decrement_turns(rules, turns) do
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
