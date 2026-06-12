defmodule Admin.Diag do
  @moduledoc "Checagens de integridade do ecossistema de plantas."

  def check_plants do
    records = Mud.Characters.by_race("plant") |> Enum.map(& &1.name) |> MapSet.new()

    # processes =
    #   DynamicSupervisor.which_children(Mud.Characters.PlantDynSupervisor)
    #   |> Enum.map(fn {_, pid, _, _} -> Registry.keys(Mud.PlantRegistry, pid) end)
    #   |> List.flatten()
    #   |> MapSet.new()

    %{
      total_records: MapSet.size(records),
      # total_processes: MapSet.size(processes),
      # records_sem_processo: MapSet.difference(records, processes) |> MapSet.size(),
      # processos_sem_record: MapSet.difference(processes, records) |> MapSet.size()
    }
  end

  def resources do
    memory = :erlang.memory() |> Keyword.take([:total, :processes, :ets, :binary, :atom]) |> Map.new()

    %{
      memory: Map.new(memory, fn {k, v} -> {k, humanize(v)} end),
      process_count: :erlang.system_info(:process_count),
      plants: DynamicSupervisor.count_children(Mud.Characters.PlantDynSupervisor),
      character_table_size: :mnesia.table_info(:character, :size),
      mnesia_dcd_bytes: humanize(mnesia_dcd_size())
    }
  end

  @doc "Top N processos por memória, com nome registrado, fila de mensagens e nome de planta (se houver)."
  def top_processes(n \\ 10) do
    Process.list()
    |> Enum.flat_map(fn pid ->
      case Process.info(pid, [:memory, :registered_name, :message_queue_len, :current_function]) do
        nil ->
          []

        info ->
          plant_name =
            case Registry.keys(Mud.PlantRegistry, pid) do
              [name] -> name
              [] -> nil
            end

          [%{
            pid: pid,
            memory: humanize(info[:memory]),
            memory_bytes: info[:memory],
            registered_name: info[:registered_name],
            plant_name: plant_name,
            message_queue_len: info[:message_queue_len],
            current_function: info[:current_function]
          }]
      end
    end)
    |> Enum.sort_by(& -&1.memory_bytes)
    |> Enum.take(n)
  end

  defp mnesia_dcd_size do
    Path.join(:mnesia.system_info(:directory), "character.DCD")
    |> File.stat()
    |> case do
      {:ok, %{size: s}} -> s
      _ -> 0
    end
  end

  defp humanize(bytes) when bytes >= 1_073_741_824, do: "#{Float.round(bytes / 1_073_741_824, 2)} GB"
  defp humanize(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 2)} MB"
  defp humanize(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 2)} KB"
  defp humanize(bytes), do: "#{bytes} B"
end
