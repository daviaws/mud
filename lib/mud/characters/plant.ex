defmodule Mud.Characters.Plant do
  use GenServer

  require Logger

  @tick_ms Application.compile_env(:mud, :world_tick_ms, 30_000)

  def child_spec(character) do
    %{
      id: character.name,
      start: {__MODULE__, :start_link, [character]},
      restart: :temporary
    }
  end

  def start_link(character) do
    GenServer.start_link(__MODULE__, character)
  end

  def init(character) do
    Process.send_after(self(), :tick, @tick_ms)
    {:ok, character}
  end

  def handle_info(:tick, character) do
    Logger.info("#{character.name} is aging")
    character = age(character)

    if character.attrs[:stage] == "dead" do
      Logger.info("#{character.name} is dying")
      Mud.Characters.delete(character.name)
      {:stop, :normal, character}
    else
      Process.send_after(self(), :tick, @tick_ms)
      {:noreply, character}
    end
  end

  defp age(character) do
    attrs = character.attrs
    age = (attrs[:age] || 0) + 1
    stages = attrs[:stages]
    duration = attrs[:stage_duration]
    stage_index = min(div(age, duration), length(stages) - 1)
    stage = Enum.at(stages, stage_index)

    new_attrs = attrs |> Map.put(:age, age) |> Map.put(:stage, stage)
    Mud.Characters.update_attrs(character.name, new_attrs)
    %{character | attrs: new_attrs}
  end
end
