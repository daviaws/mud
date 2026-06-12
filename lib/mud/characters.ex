defmodule Mud.Characters do
  @moduledoc """
  Persistência do personagem em Mnesia (tabela `:character`, `disc_copies`).

  Um personagem é, por ora, `{nome, sala, criado_em, visto_em}`, chaveado
  pelo nome. O estado sobrevive a restart: ao logar de novo, o jogador
  volta para a última sala em que estava.

  `setup/1` é chamado uma vez no boot (em `Mud.Application`). É
  idempotente: cria schema e tabela na primeira vez, e nas seguintes
  apenas aguarda a tabela carregar do disco.

  Mnesia Notes
    Initial node
      Start mnesia with :mnesia.start()
      Change the copy type with :mnesia.change_table_copy_type(:schema, [node()], copy_type), if you e.g. use disc copies
      Create the table :mnesia.create_table(table, table_def)
      Wait for the table to be ready :mnesia.wait_for_tables([table], timeout).

    Join cluster
      Since Pow starts all nodes as disc copies, I'm purging old data and removing the table copy from the cluster
      Start mnesia with :mnesia.start()
      Join cluster with :mnesia.change_config([:extra_db_nodes, [cluster_node]])
      Change table copy type :mnesia.change_table_copy_type(:schema, [node()], copy_type), if you e.g. use disc copies
      Sync table :mnesia.add_table_copy([table, node(), copy_type])
      Wait for the table to be ready :mnesia.wait_for_tables([table], timeout).
  """
  require Record

  require Logger

  @table :character
  @attrs [:name, :room, :attrs, :created_at, :last_seen]
  Record.defrecord(:character, @attrs)

  @doc "Prepara o Mnesia em disco. Idempotente; seguro de chamar todo boot."
  def setup() do
    case :mnesia.change_table_copy_type(:schema, node(), :disc_copies) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :schema, _, :disc_copies}} -> :ok
      {:aborted, reason} -> raise "Mnesia schema upgrade: #{inspect(reason)}"
    end

    case :mnesia.create_table(@table, attributes: @attrs, disc_copies: [node()], index: [:room]) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @table}} -> :ok
      {:aborted, reason} -> raise "Mnesia tabela #{@table}: #{inspect(reason)}"
    end

    :ok = :mnesia.wait_for_tables([@table], 10_000)
  end

  @doc """
  Carrega o personagem pelo nome; cria com `default_room` se for novo.
  Atualiza `last_seen` e retorna um `%Mud.Character{}` pronto para sessão.
  """
  def load_or_create(name, default_room, attrs \\ %{}) do
    {:atomic, rec} =
      :mnesia.transaction(fn ->
        case :mnesia.read(@table, name) do
          [rec] ->
            updated = character(rec, last_seen: now())
            :mnesia.write(updated)
            updated

          [] ->
            rec =
              character(
                name: name,
                room: default_room,
                attrs: attrs,
                created_at: now(),
                last_seen: now()
              )

            :mnesia.write(rec)
            rec
        end
      end)

    to_struct(rec)
  end

  @doc "Retorna todos os personagens em uma sala como lista de `%Character{}`."
  def by_room(room_id) do
    {:atomic, recs} =
      :mnesia.transaction(fn ->
        :mnesia.index_read(@table, room_id, :room)
      end)

    Enum.map(recs, &to_struct/1)
  end

  @doc "Retorna todos os personagens tipo planta como lista de `%Character{}`."
  def by_race(race) do
    :mnesia.dirty_match_object({@table, :_, :_, :_, :_, :_})
    |> Enum.filter(fn rec ->
      character(rec, :attrs)[:race] == race or
        character(rec, :attrs)["race"] == race
    end)
    |> Enum.map(&to_struct/1)
  end

  @doc "Persiste a sala atual do personagem."
  def set_room(name, room) do
    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        rec =
          case :mnesia.read(@table, name) do
            [r] ->
              character(r, room: room, last_seen: now())

            [] ->
              character(name: name, room: room, attrs: %{}, created_at: now(), last_seen: now())
          end

        :mnesia.write(rec)
      end)

    :ok
  end

  @doc "Lê o personagem como `%Mud.Character{}`, ou `nil` se não existir."
  def get(name) do
    {:atomic, res} =
      :mnesia.transaction(fn ->
        case :mnesia.read(@table, name) do
          [r] -> to_struct(r)
          [] -> nil
        end
      end)

    res
  end

  @doc "Atualiza os attrs de um personagem."
  def update_attrs(name, new_attrs) do
    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        case :mnesia.read(@table, name) do
          [rec] ->
            :mnesia.write(character(rec, attrs: new_attrs, last_seen: now()))

          [] ->
            :ok
        end
      end)

    :ok
  end

  @doc "Remove um personagem pelo nome. Irreversível."
  def delete(name) do
    kill_process(name)

    mnesia_delete(name)
    |> case do
      {:atomic, :ok} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  @doc "Remove vários personagens de uma vez: mata os processos primeiro, depois uma única transação Mnesia."
  def delete_many(names) do
    Logger.info("Deletando #{length(names)} personagem(ns)")
    Enum.each(names, &kill_process/1)

    :mnesia.transaction(fn ->
      Enum.each(names, &:mnesia.delete(@table, &1, :write))
    end)
    |> case do
      {:atomic, :ok} -> :ok
      {:aborted, reason} -> {:error, reason}
    end
  end

  defp kill_process(name) do
    case Registry.lookup(Mud.PlantRegistry, name) do
      [{pid, _}] -> Process.exit(pid, :kill)
      [] -> :ok
    end
  end

  def mnesia_delete(name) do
    :mnesia.transaction(fn -> :mnesia.delete(@table, name, :write) end)
  end

  @doc "Remove todas as plantas de uma sala: termina o processo e remove do Mnesia."
  def delete_plants(room_id) do
    room_id
    |> by_room()
    |> Enum.filter(&(&1.attrs[:race] == "plant"))
    |> Enum.map(& &1.name)
    |> delete_many()
  end

  ## Helpers

  defp to_struct(rec) do
    %Mud.Characters.Character{
      name: character(rec, :name),
      room: character(rec, :room),
      attrs: character(rec, :attrs) || %{}
    }
  end

  defp now, do: System.system_time(:second)
end
