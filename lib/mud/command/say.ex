defmodule Mud.Commands.Say do
  @moduledoc "Fala em voz alta na sala."
  @behaviour Mud.Commands.Command

  @impl true
  def names, do: ~w(dizer say)

  @impl true
  def run(_verb, "", session), do: {session, "Dizer o quê?\r\n"}

  def run(_verb, text, session) do
    Mud.Room.say(session.character.room, session.character.name, text)
    {session, "Você diz: #{text}\r\n"}
  end
end
