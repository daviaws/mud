defmodule Mud.Characters.PlantSupervisor do
  use GenServer

  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start_plant(character) do
    DynamicSupervisor.start_child(
      Mud.Characters.PlantDynSupervisor,
      {Mud.Characters.Plant, character}
    )
  end

  @doc "Sobe processos só para plantas sem processo vivo registrado."
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  def init(_) do
    {:ok, _} =
      DynamicSupervisor.start_link(
        name: Mud.Characters.PlantDynSupervisor,
        strategy: :one_for_one
      )

    load_plants()
    {:ok, %{}}
  end

  def handle_call(:reload, _from, state) do
    load_plants()
    {:reply, :ok, state}
  end

  defp load_plants do
    plants = Mud.Characters.by_race("plant")
    Logger.info("PlantSupervisor verificando #{length(plants)} planta(s)")

    Enum.each(plants, fn plant ->
      case start_plant(plant) do
        {:ok, _pid} -> Logger.info("#{plant.name} iniciada")
        {:error, {:already_started, _pid}} -> :ok
        {:error, reason} -> Logger.warning("#{plant.name} falhou: #{inspect(reason)}")
      end
    end)
  end
end
