defmodule Mud.Characters.Plant do
  use GenServer

  require Logger

  @reproductive_stages ["mature", "old"]

  def child_spec(character) do
    %{
      id: character.name,
      start: {__MODULE__, :start_link, [character]},
      restart: :temporary
    }
  end

  def start_link(character) do
    GenServer.start_link(__MODULE__, character, name: via(character.name))
  end

  def init(character) do
    schedule_tick()
    {:ok, character}
  end

  def handle_info(:tick, character) do
    Logger.info("#{character.name} is aging")
    character = age(character)

    character =
      if pregnant?(character) do
        release_seed(character)
      else
        character
      end

    if character.attrs[:stage] == "dead" do
      Logger.info("#{character.name} is dying")
      Mud.Characters.mnesia_delete(character.name)
      {:stop, :normal, character}
    else
      character =
        if character.attrs[:stage] in @reproductive_stages do
          maybe_conceive(character)
        else
          character
        end

      schedule_tick()
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
    energy = adjust_energy(attrs[:energy_level] || 1.0)

    new_attrs =
      attrs
      |> Map.put(:age, age)
      |> Map.put(:stage, stage)
      |> Map.put(:energy_level, energy)

    Mud.Characters.update_attrs(character.name, new_attrs)
    %{character | attrs: new_attrs}
  end

  defp adjust_energy(energy) do
    delta = Enum.random([-1, 0, 1])
    max(energy + delta, 1.0)
  end

  ## Reprodução

  defp pregnant?(character), do: character.attrs[:pregnant_with] != nil

  defp maybe_conceive(character) do
    if can_spawn?(character) do
      case elegible_partners(character) do
        [] -> character
        candidates -> conceive(character, Enum.random(candidates))
      end
    else
      character
    end
  end

  defp elegible_partners(character) do
    character.room
    |> Mud.Characters.by_room()
    |> Enum.filter(&(&1.attrs[:plant_type] == character.attrs[:plant_type]))
    |> Enum.filter(fn _ -> :rand.uniform() <= 0.3 end)
    |> Enum.filter(&compatible_partner?(character, &1))
  end

  defp can_spawn?(%{attrs: %{gender: gender}}), do: gender in ["female", "hermaphrodite"]

  defp compatible_partner?(character, other) do
    other.name != character.name and
      other.attrs[:race] == "plant" and
      other.attrs[:plant_type] == character.attrs[:plant_type] and
      other.attrs[:stage] in @reproductive_stages and
      other.attrs[:gender] in ["male", "hermaphrodite"]
  end

  defp conceive(character, partner) do
    parent_attrs = character.attrs

    energy =
      ((parent_attrs[:energy_level] + partner.attrs[:energy_level]) / 2)
      |> adjust_energy()

    seed_attrs =
      parent_attrs
      |> Map.put(:age, 0)
      |> Map.put(:stage, "seed")
      |> Map.put(:gender, roll_gender(parent_attrs, partner.attrs))
      |> Map.put(:energy_level, energy)

    new_attrs = Map.put(parent_attrs, :pregnant_with, seed_attrs)

    Mud.Characters.update_attrs(character.name, new_attrs)
    Logger.info("Reprodução: #{character.name} concebeu com #{partner.name}")
    %{character | attrs: new_attrs}
  end

  defp release_seed(character) do
    seed_attrs = character.attrs[:pregnant_with]

    seed_name =
      "#{character.attrs[:plant_type]}-#{:erlang.unique_integer([:positive, :monotonic])}"

    room = pick_seed_room(character.room)

    child = Mud.Characters.load_or_create(seed_name, room, seed_attrs)
    Mud.Characters.PlantSupervisor.start_plant(child)

    cleared_attrs = Map.drop(character.attrs, [:pregnant_with])
    Mud.Characters.update_attrs(character.name, cleared_attrs)

    Logger.info("Reprodução: #{character.name} lança semente -> #{seed_name} (#{room})")
    %{character | attrs: cleared_attrs}
  end

  defp roll_gender(parent_attrs, partner_attrs) do
    parents_have_hermaphrodite? =
      parent_attrs[:gender] == "hermaphrodite" or partner_attrs[:gender] == "hermaphrodite"

    if parents_have_hermaphrodite? and :rand.uniform() > 0.75 do
      "hermaphrodite"
    else
      Enum.random(["male", "female"])
    end
  end

  defp pick_seed_room(current_room) do
    case Mud.Rooms.get(current_room) do
      %{exits: exits} when map_size(exits) > 0 ->
        exits |> Map.values() |> Enum.random()

      _ ->
        current_room
    end
  end

  defp tick_ms, do: Application.get_env(:mud, :world_tick_ms, 30_000)

  defp schedule_tick(), do: Process.send_after(self(), :tick, tick_ms())

  defp via(name), do: {:via, Registry, {Mud.PlantRegistry, name}}
end
