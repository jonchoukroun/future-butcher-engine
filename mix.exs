defmodule FutureButcherEngine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :future_butcher_engine,
      version: "0.1.0",
      elixir: "~> 1.7.4",
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {FutureButcherEngine.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"}
    ]
  end
end
