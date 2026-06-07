defmodule Mud.World do
  @moduledoc """
  Sobe o conjunto inicial de salas. Cada sala é um processo supervisionado;
  se uma cair, é reiniciada de forma independente das outras.
  """
  use Supervisor

  @start_room :praca

  def start_room, do: @start_room

  def start_link(_), do: Supervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    rooms = [
      %{
        id: :praca,
        name: "Praça Central",
        description:
          "Uma praça de pedra com um chafariz seco no centro. " <>
            "Pombos fingem indiferença. Há saídas ao norte e a leste.",
        exits: %{"norte" => :taverna, "leste" => :biblioteca}
      },
      %{
        id: :taverna,
        name: "A Taverna do Corvo",
        description:
          "Mesas de madeira encardida e cheiro de cerveja velha. " <>
            "A praça fica ao sul.",
        exits: %{"sul" => :praca}
      },
      %{
        id: :biblioteca,
        name: "Biblioteca Empoeirada",
        description:
          "Prateleiras infinitas se perdem na penumbra; o silêncio tem peso. " <>
            "A praça fica a oeste.",
        exits: %{"oeste" => :praca}
      }
    ]

    children =
      for room <- rooms do
        Supervisor.child_spec({Mud.Room, room}, id: room.id)
      end

    Supervisor.init(children, strategy: :one_for_one)
  end
end
