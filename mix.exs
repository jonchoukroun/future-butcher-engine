defmodule FutureButcherEngine.Mixfile do
  use Mix.Project

  def project do
    [
      app: :future_butcher_engine,
      version: "1.3.0",
      elixir: "~> 1.13.4",
      description: description(),
      package: package(),
      source_url: "https://github.com/jonchoukroun/future-butcher-engine",
      homepage_url: "https://www.futurebutcher.com",
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
      {:jason, "~> 1.1"},
      {:ex_doc, "~> 0.19", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Game engine for Future Butcher."
  end

  defp package do
    [
      licenses: ["GPL-3.0-only"],
      links: %{"GitHub" => "https://github.com/jonchoukroun/future-butcher-engine"}
    ]
  end
end
