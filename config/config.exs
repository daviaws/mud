import Config

config :mud, MudWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [formats: [html: MudWeb.ErrorHTML], layout: false],
  pubsub_server: Mud.PubSub,
  live_view: [signing_salt: "mudmudmud"],
  secret_key_base: "mud_dev_secret_key_base_min_64_chars_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
  server: true

config :mud, :phoenix_json_library, Jason

config :logger, level: :info

config :logger, :console, async: true
