defmodule Mud.World do
  @moduledoc """
  Sobe o conjunto inicial de salas. Cada sala é um processo supervisionado;
  se uma cair, é reiniciada de forma independente das outras.
  """
  use Supervisor

  @start_room "central.rising.praca_central"

  def start_room, do: @start_room

  def start_link(_), do: Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    rooms = load_rooms()

    children =
      for room <- rooms do
        Supervisor.child_spec({Mud.Room, room}, id: room.id)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp load_rooms do
    :mud
    |> :code.priv_dir()
    |> Path.join("rooms/*.toml")
    |> Path.wildcard()
    |> Enum.map(fn path ->
      {:ok, data} = Toml.decode_file(path)
      %{
        id: data["id"],
        name: data["name"],
        description: String.trim(data["description"]),
        exits: data["exits"] || %{}
      }
    end)
  end
end
