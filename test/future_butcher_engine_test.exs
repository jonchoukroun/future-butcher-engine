defmodule FutureButcherEngineTest do
  use ExUnit.Case
  doctest FutureButcherEngine

  test "greets the world" do
    assert FutureButcherEngine.hello() == :world
  end
end
