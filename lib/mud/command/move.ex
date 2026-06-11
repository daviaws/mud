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
        from = from_direction(dest, character.room)
        {%{session | character: new_character}, Mud.Rooms.Room.enter(dest, character.name, from)}

      :error ->
        {session, "Não há saída nessa direção.\r\n"}
    end
  end

  defp from_direction(dest_room, origin_room) do
    case Mud.Rooms.get(dest_room) do
      %{exits: exits} ->
        exits
        |> Enum.find(fn {_dir, room} -> room == origin_room end)
        |> case do
          {dir, _} -> dir
          nil -> nil
        end
      _ -> nil
    end
  end
end
