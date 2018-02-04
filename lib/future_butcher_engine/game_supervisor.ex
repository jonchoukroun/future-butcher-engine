defmodule FutureButcherEngine.GameSupervisor do
  use Supervisor
  alias FutureButcherEngine.Game

  def start_link(_options) do
    Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(:ok), do: Supervisor.init([Game], strategy: :simple_one_for_one)

end