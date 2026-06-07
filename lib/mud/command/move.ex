defmodule Mud.Commands.Move do
  @moduledoc """
  Move o jogador por uma saída. Invocável pela direção direta
  (`norte`) ou pela forma com verbo (`ir norte` / `go north`).
  """
  @behaviour Mud.Commands.Command

  @impl true
  def names, do: ~w(norte sul leste oeste ir go)

  @impl true
  def run(verb, args, session) do
    dir = if verb in ~w(ir go), do: String.trim(args), else: verb

    case Mud.Room.exit_to(session.room, dir) do
      {:ok, dest} ->
        Mud.Room.leave(session.room)
        {%{session | room: dest}, Mud.Room.enter(dest, session.name)}

      :error ->
        {session, "Não há saída nessa direção.\r\n"}
    end
  end
end
