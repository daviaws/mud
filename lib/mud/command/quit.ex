defmodule Mud.Commands.Quit do
  @moduledoc "Sinaliza desconexão. O fechamento do socket é do transporte."
  @behaviour Mud.Commands.Command

  @impl true
  def names, do: ~w(sair quit)

  @impl true
  def run(_verb, _args, session) do
    Mud.Sessions.unregister(session.character.name)
    Mud.Rooms.Room.leave(session.character.room)
    {Map.put(session, :quit?, true), "Até a próxima.\r\n"}
  end
end
