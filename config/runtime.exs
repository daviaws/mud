import Config

if config_env() == :prod do
  config :esbuild,
    mud: [
      args: ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --loader:.css=css --minify),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
end

config :mud, start_room: System.get_env("MUD_START_ROOM", "central.rising.praca_central")

config :mud, :world_tick_ms, System.get_env("WORLD_TICK_MS", "30000") |> String.to_integer()
