import Config

config :mud, start_room: System.get_env("MUD_START_ROOM", "central.rising.praca_central")

config :mud, :world_tick_ms, System.get_env("WORLD_TICK_MS", "30000") |> String.to_integer()
