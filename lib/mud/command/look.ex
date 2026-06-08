defmodule Mud.Commands.Look do
  @moduledoc "Olha a sala atual."
  @behaviour Mud.Commands.Command

  @impl true
  def names, do: ~w(olhar look l)

  @impl true
  def run(_verb, _args, session) do
    {session, Mud.Room.look(session.character.room)}
  end
end
