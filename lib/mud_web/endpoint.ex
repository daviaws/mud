defmodule MudWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :mud

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [
      connect_info: [
        session: [store: :cookie, key: "_mud_key", signing_salt: "mudmudmud", same_site: "Lax"]
      ]
    ]
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, store: :cookie, key: "_mud_key", signing_salt: "mudmudmud", same_site: "Lax")

  plug Plug.Static,
    at: "/",
    from: :mud,
    gzip: false,
    only: ~w(assets)

  plug(MudWeb.Router)
end
