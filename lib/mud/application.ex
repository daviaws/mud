defmodule Mud.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @port 4040

  @impl true
  def start(_type, _args) do
    :mnesia.system_info(:directory)
    |> to_string()
    |> File.mkdir_p!()

    :ok = :mnesia.start()
    :ok = Mud.Characters.setup()
    :ok = Mud.Rooms.setup()
    :ok = Mud.Seeder.setup()
    :ok = Mud.Seeder.run(false)

    children = [
      {Registry, keys: :unique, name: Mud.RoomRegistry},
      {Registry, keys: :unique, name: Mud.SessionRegistry},
      {Registry, keys: :unique, name: Mud.PlantRegistry},
      {Phoenix.PubSub, name: Mud.PubSub},
      Mud.World,
      MudWeb.Endpoint,
      {ThousandIsland,
       port: @port,
       handler_module: Mud.Server,
       read_timeout: :infinity,
       transport_options: [keepalive: true]}
    ]

    opts = [strategy: :one_for_one, name: Mud.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        require Logger
        Logger.info("MUD ouvindo em telnet://localhost:#{@port}")
        {:ok, pid}

      other ->
        other
    end
  end
end
