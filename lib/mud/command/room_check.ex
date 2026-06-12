defmodule Mud.Commands.RoomCheck do
  @moduledoc "Lista os personagens da sala atual e seus atributos."
  @behaviour Mud.Commands.Command

  @impl true
  def names, do: ~w(room_check)

  @impl true
  def run(_verb, _args, session) do
    output =
      session.character.room
      |> Mud.Characters.by_room()
      |> Enum.map(&format_character/1)
      |> Enum.join("\r\n")

    {session, "== Personagens em #{session.character.room} ==\r\n#{output}\r\n"}
  end

  defp format_character(character) do
    [character.name | format_tree(character.attrs, "")]
    |> Enum.join("\r\n")
  end

  defp format_tree(map, indent) do
    map
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.flat_map(&format_entry(&1, indent))
  end

  defp format_entry({key, value}, indent) when is_map(value) and map_size(value) > 0 do
    ["#{indent}|- #{key}" | format_tree(value, indent <> "   ")]
  end

  defp format_entry({key, value}, indent) do
    ["#{indent}|- #{key}: #{format_value(value)}"]
  end

  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value)
end
