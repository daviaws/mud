defmodule Mud.Characters.PlantSupervisor do
  @moduledoc """
  Sobe um `Mud.Characters.Plant` por sala (não por planta). `reload/0`
  agrupa o que está no Mnesia por sala: salas novas ganham um `Plant`;
  salas já ativas recebem só as plantas ainda não rastreadas.
  """
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Sobe `Plant`s para salas novas; adiciona plantas novas a salas já ativas."
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  def init(_) do
    {:ok, _} =
      DynamicSupervisor.start_link(
        name: Mud.Characters.PlantDynSupervisor,
        strategy: :one_for_one
      )

    load_rooms()
    {:ok, %{}}
  end

  def handle_call(:reload, _from, state) do
    load_rooms()
    {:reply, :ok, state}
  end

  defp load_rooms do
    Mud.Characters.by_race("plant")
    |> Enum.group_by(& &1.room)
    |> Enum.each(fn {room_id, plants} ->
      case Registry.lookup(Mud.PlantRegistry, room_id) do
        [{_pid, _}] ->
          known = MapSet.new(Mud.Characters.Plant.plant_names(room_id))
          new_plants = Enum.reject(plants, &MapSet.member?(known, &1.name))

          if new_plants != [] do
            Logger.info("Plant(#{room_id}): adicionando #{length(new_plants)} planta(s) nova(s)")
            Mud.Characters.Plant.add_plants(room_id, new_plants)
          end

        [] ->
          start_room(room_id, plants)
      end
    end)
  end

  defp start_room(room_id, plants) do
    case DynamicSupervisor.start_child(
           Mud.Characters.PlantDynSupervisor,
           {Mud.Characters.Plant, {room_id, plants}}
         ) do
      {:ok, _pid} ->
        Logger.info("Plant(#{room_id}) iniciado com #{length(plants)} planta(s)")

      {:error, {:already_started, _pid}} ->
        :ok

      {:error, reason} ->
        Logger.warning("Plant(#{room_id}) falhou: #{inspect(reason)}")
    end
  end
end
