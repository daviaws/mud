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

  def init(_) do
    {:ok, _} =
      DynamicSupervisor.start_link(
        name: Mud.Characters.PlantDynSupervisor,
        strategy: :one_for_one
      )

    load_plants()
    {:ok, %{}}
  end

  defp load_plants do
    Mud.Characters.by_race("plant")
    |> tap(fn plants -> Logger.info("PlantSupervisor carregando #{length(plants)} plantas") end)
    |> Enum.each(&start_plant/1)
  end
end
