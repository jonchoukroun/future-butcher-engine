defmodule FutureButcherEngine.Game do
  use GenServer
  alias FutureButcherEngine.{Game, Player, Rules}

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
      player: Player.new(game_rules.health, game_rules.funds)}}
  end

end