defmodule Mud.Characters.PlantSupervisor do
  @moduledoc """
  Sobe e gerencia processos `Plant`, e mantém um índice ETS de nomes
  de "doadores" de reprodução por `{sala, plant_type}`.

  O refresh é por sala e reativo: a primeira planta daquela sala que
  pedir `elegible_partners/1` depois de `world_tick_ms` desde o último
  refresh dispara o recálculo (assíncrono); as demais, no mesmo
  intervalo, leem o índice já calculado sem disparar nada.

  O índice guarda só `plant_type -> [nomes]` (estágio reprodutivo +
  gênero `male`/`hermaphrodite`, já filtrados no refresh) — leve, sem
  cópia de structs. A cada pedido, `elegible_partners/1` sorteia até
  `@max_donors` nomes (excluindo o próprio), confirma que o processo
  ainda está vivo via `Mud.PlantRegistry` e resolve o `%Character{}`
  atual via `Mud.Characters.get/1`.
  """
  use GenServer

  require Logger

  @reproductive_stages ["mature", "old"]
  @max_donors 3
  @table __MODULE__

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

  @doc "Até #{@max_donors} parceiros elegíveis (vivos, com estado atual) para `character`."
  def elegible_partners(character) do
    maybe_trigger_refresh(character.room)

    names =
      case :ets.lookup(@table, {:donors, character.room, character.attrs[:plant_type]}) do
        [{_, names}] -> names
        [] -> []
      end

    names
    |> Enum.reject(&(&1 == character.name))
    |> Enum.take_random(@max_donors)
    |> Enum.flat_map(&resolve/1)
  end

  defp resolve(name) do
    case Registry.lookup(Mud.PlantRegistry, name) do
      [{_pid, _}] ->
        case Mud.Characters.get(name) do
          nil -> []
          character -> [character]
        end

      [] ->
        []
    end
  end

  def init(_) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

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

  def handle_cast({:refresh_room, room_id}, state) do
    refresh_room(room_id)
    {:noreply, state}
  end

  defp maybe_trigger_refresh(room_id) do
    ms = Application.get_env(:mud, :world_tick_ms)
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@table, {:last_refresh, room_id}) do
      [{_, last}] when now - last < ms ->
        :ok

      _ ->
        :ets.insert(@table, {{:last_refresh, room_id}, now})
        GenServer.cast(__MODULE__, {:refresh_room, room_id})
    end
  end

  defp refresh_room(room_id) do
    room_id
    |> Mud.Characters.by_room()
    |> Stream.filter(&(&1.attrs[:race] == "plant"))
    |> Enum.group_by(& &1.attrs[:plant_type])
    |> Enum.each(fn {plant_type, plants} ->
      names =
        plants
        |> Stream.filter(&(&1.attrs[:stage] in @reproductive_stages))
        |> Stream.filter(&(&1.attrs[:gender] in ["male", "hermaphrodite"]))
        |> Enum.map(& &1.name)

      :ets.insert(@table, {{:donors, room_id, plant_type}, names})
    end)
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
