defmodule Mud.MixProject do
  use Mix.Project

  def project do
    [
      app: :mud,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      deps_warnings: false
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia],
      mod: {Mud.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:thousand_island, "~> 1.5"},
      {:toml, "~> 0.7"}
    ]
  end
end
