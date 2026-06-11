defmodule Mud.Commands.Move do
  @moduledoc """
  Move o jogador por uma saída. Invocável pela direção direta
  (`norte`) ou pela forma com verbo (`ir norte` / `go north`).
  Persiste a nova sala no Mnesia imediatamente.
  """
  @behaviour Mud.Commands.Command

  @impl true
  def names, do: ~w(norte sul leste oeste ir go)

  @impl true
  def run(verb, args, session) do
    dir = if verb in ~w(ir go), do: String.trim(args), else: verb
    character = session.character

    case Mud.Rooms.Room.exit_to(character.room, dir) do
      {:ok, dest} ->
        Mud.Rooms.Room.leave(character.room, dir)
        Mud.Characters.set_room(character.name, dest)
        new_character = %{character | room: dest}
        {%{session | character: new_character}, Mud.Rooms.Room.enter(dest, character.name)}

      :error ->
        {session, "Não há saída nessa direção.\r\n"}
    end
  end
end
