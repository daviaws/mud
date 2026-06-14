defmodule Mud.MixProject do
  use Mix.Project

  def project do
    [
      app: :mud,
      version: "0.1.0",
      elixir: "~> 1.20",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
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
      {:toml, "~> 0.7"},
      {:phoenix, "~> 1.8"},
      {:phoenix_live_view, "~> 1.1"},
      {:phoenix_html, "~> 4.3"},
      {:bandit, "~> 1.1"},
      {:observer_web, "~> 0.2"},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev}
    ]
  end

  defp aliases do
    [
      "assets.build": ["esbuild mud"],
      "assets.watch": ["esbuild mud --watch"],
      "assets.deploy": ["esbuild mud --minify"],
      "assets.setup": [
        "cmd --cd assets npm install",
        "esbuild mud"
      ]
    ]
  end
end
