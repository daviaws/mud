defmodule Mud.Characters.Plant do
  @moduledoc """
  Um processo por sala. Mantém em memória a lista de plantas daquela
  sala (`%Character{}`) e, a cada `world_tick_ms`, itera todas de uma
  vez: envelhece, processa gestação/parto, e tenta concepção usando
  doadores calculados a partir da própria lista.

  Após cada tick, publica em ETS público (`@table`) o índice
  `{room_id, plant_type} -> [nomes de doadores]` e a população por
  tipo — leitura externa (status, diagnóstico, futuros agentes) sem
  `GenServer.call` no processo da sala.

  Persistência por entidade é preservada: cada planta que muda de
  estágio é gravada via `Mud.Characters.update_attrs/2`; mortes via
  `delete/1`; sementes via `create/3`.
  """
  use GenServer

  require Logger

  @reproductive_stages ["mature", "old"]
  @table Mud.Characters.PlantIndex
  @donors_capacity 100

  ## API

  def child_spec({room_id, plants}) do
    %{
      id: {__MODULE__, room_id},
      start: {__MODULE__, :start_link, [{room_id, plants}]},
      restart: :temporary
    }
  end

  def start_link({room_id, plants}) do
    GenServer.start_link(__MODULE__, {room_id, plants}, name: via(room_id))
  end

  @doc "Adiciona plantas (boot/reload, ou sementes vindas de outra sala) à lista local."
  def add_plants(room_id, characters) when is_list(characters) do
    GenServer.cast(via(room_id), {:add_plants, characters})
  end

  @doc "Nomes das plantas atualmente rastreadas por esta sala."
  def plant_names(room_id) do
    GenServer.call(via(room_id), :plant_names)
  end

  @doc "Doadores publicados (nomes) para `{room_id, plant_type}`."
  def donors(room_id, plant_type) do
    case :ets.lookup(@table, {:donors, room_id, plant_type}) do
      [{_, names}] -> names
      [] -> []
    end
  end

  @doc "População publicada de `{room_id, plant_type}`."
  def population(room_id, plant_type) do
    case :ets.lookup(@table, {:population, room_id, plant_type}) do
      [{_, count}] -> count
      [] -> 0
    end
  end

  defp via(room_id), do: {:via, Registry, {Mud.PlantRegistry, room_id}}

  ## Callbacks

  def init({room_id, plants}) do
    ensure_table()
    publish_index(room_id, plants)
    schedule_tick()
    {:ok, %{room_id: room_id, plants: plants}}
  end

  def handle_call(:plant_names, _from, state) do
    {:reply, Enum.map(state.plants, & &1.name), state}
  end

  def handle_cast({:add_plants, characters}, state) do
    {:noreply, %{state | plants: characters ++ state.plants}}
  end

  def handle_info(:tick, state) do
    donors_by_type = group_donors(state.plants)
    results = Enum.map(state.plants, &tick_plant(&1, donors_by_type))

    persist(results)

    alive_plants = for {:alive, plant, _persist?, _seed} <- results, do: plant
    seeds = results |> Enum.map(&extract_seed/1) |> Enum.reject(&is_nil/1)
    local_seeds = spawn_seeds(seeds, state.room_id)

    if results != [] do
      Logger.info("Plant(#{state.room_id}): #{length(alive_plants)} viva(s), #{length(seeds)} semente(s)")
    end

    final_plants = alive_plants ++ local_seeds
    publish_index(state.room_id, final_plants)

    schedule_tick()
    {:noreply, %{state | plants: final_plants}}
  end

  defp persist(results) do
    {updates, deletes} =
      Enum.reduce(results, {[], []}, fn
        {:alive, plant, true, _seed}, {u, d} -> {[plant | u], d}
        {:alive, _plant, false, _seed}, acc -> acc
        {:dead, name, _seed}, {u, d} -> {u, [name | d]}
      end)

    Mud.Characters.bulk_update(updates, deletes)
  end

  defp extract_seed({:alive, _plant, _persist?, seed}), do: seed
  defp extract_seed({:dead, _name, seed}), do: seed

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end

      _ ->
        :ok
    end
  end

  defp publish_index(room_id, plants) do
    plants
    |> Enum.group_by(& &1.attrs[:plant_type])
    |> Enum.each(fn {plant_type, group} ->
      donors =
        group
        |> Stream.filter(&(&1.attrs[:stage] in @reproductive_stages))
        |> Stream.filter(&(&1.attrs[:gender] in ["male", "hermaphrodite"]))
        |> Enum.map(& &1.name)

      :ets.insert(@table, {{:donors, room_id, plant_type}, donors})
      :ets.insert(@table, {{:population, room_id, plant_type}, length(group)})
    end)
  end

  defp tick_plant(plant, donors_by_type) do
    previous_stage = plant.attrs[:stage]
    plant = age(plant)

    {plant, seed} =
      if pregnant?(plant) do
        release_seed(plant)
      else
        {plant, nil}
      end

    if plant.attrs[:stage] == "dead" do
      {:dead, plant.name, seed}
    else
      plant =
        if plant.attrs[:stage] in @reproductive_stages do
          maybe_conceive(plant, donors_by_type)
        else
          plant
        end

      persist? = plant.attrs[:stage] != previous_stage or seed != nil
      {:alive, plant, persist?, seed}
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

    %{character | attrs: new_attrs}
  end

  defp adjust_energy(energy) do
    delta = Enum.random([-1, 0, 1])
    max(energy + delta, 1.0)
  end

  ## Reprodução

  defp pregnant?(character), do: character.attrs[:pregnant_with] != nil

  defp group_donors(plants) do
    plants
    |> Enum.filter(&(&1.attrs[:stage] in @reproductive_stages))
    |> Enum.filter(&(&1.attrs[:gender] in ["male", "hermaphrodite"]))
    |> Enum.group_by(& &1.attrs[:plant_type])
  end

  defp maybe_conceive(character, donors_by_type) do
    if can_spawn?(character) do
      donors = Map.get(donors_by_type, character.attrs[:plant_type], [])

      density = length(donors) / @donors_capacity
      chance = max(1 - density, 0.10)
      if :rand.uniform() < chance do
        case Enum.reject(donors, &(&1.name == character.name)) do
          [] -> character
          candidates -> conceive(character, Enum.random(candidates))
        end
      else
        character
      end
    else
      character
    end
  end

  defp can_spawn?(%{attrs: %{gender: gender}}), do: gender in ["female", "hermaphrodite"]

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

    Logger.debug("Reprodução: #{character.name} concebeu com #{partner.name}")
    %{character | attrs: new_attrs}
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

  defp release_seed(character) do
    seed_attrs = character.attrs[:pregnant_with]
    cleared_attrs = Map.drop(character.attrs, [:pregnant_with])
    {%{character | attrs: cleared_attrs}, seed_attrs}
  end

  defp spawn_seeds(seeds, room_id) do
    Enum.flat_map(seeds, fn seed_attrs ->
      target_room = pick_seed_room(room_id)
      name = "#{seed_attrs[:plant_type]}-#{:erlang.unique_integer([:positive, :monotonic])}"
      child = Mud.Characters.create(name, target_room, seed_attrs)

      cond do
        target_room == room_id ->
          [child]

        match?([_], Registry.lookup(Mud.PlantRegistry, target_room)) ->
          add_plants(target_room, [child])
          []

        true ->
          Logger.warning(
            "Semente #{name} criada em #{target_room} sem Plant ativo; será pega no próximo reload"
          )

          []
      end
    end)
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
end
