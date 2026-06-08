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

  @table :character
  @attrs [:name, :room, :attrs, :created_at, :last_seen]
  Record.defrecord(:character, @attrs)

  @doc "Prepara o Mnesia em disco. Idempotente; seguro de chamar todo boot."
  def setup() do
    :mnesia.system_info(:directory)
    |> File.mkdir_p!()

    :ok = :mnesia.start()

    :mnesia.change_table_copy_type(:schema, node(), :disc_copies)

    case :mnesia.create_table(@table, attributes: @attrs, disc_copies: [node()]) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @table}} -> :ok
      {:aborted, reason} -> raise "Mnesia tabela #{@table}: #{inspect(reason)}"
    end

    :ok = :mnesia.wait_for_tables([@table], 10_000)
  end

  @doc """
  Carrega o personagem pelo nome; cria com `default_room` se for novo.
  Atualiza `last_seen` e retorna a sala onde o jogador deve entrar.
  """
  def load_or_create(name, default_room) do
    {:atomic, character} =
      :mnesia.transaction(fn ->
        case :mnesia.read(@table, name) do
          [rec] ->
            :mnesia.write(character(rec, last_seen: now()))
            rec

          [] ->
            rec = character(name: name, room: default_room, attrs: %{}, created_at: now(), last_seen: now())
            :mnesia.write(rec)
            rec
        end
      end)

    %Mud.Character{
      name: character(character, :name),
      room: character(character, :room),
      attrs: character(character, :attrs)
    }
  end

  @doc "Persiste a sala atual do personagem."
  def set_room(name, room) do
    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        rec =
          case :mnesia.read(@table, name) do
            [r] -> character(r, room: room, last_seen: now())
            [] -> character(name: name, room: room, created_at: now(), last_seen: now())
          end

        :mnesia.write(rec)
      end)

    :ok
  end

  @doc "Lê o personagem como mapa, ou `nil` se não existir."
  def get(name) do
    {:atomic, res} =
      :mnesia.transaction(fn ->
        case :mnesia.read(@table, name) do
          [r] ->
            %{
              name: character(r, :name),
              room: character(r, :room),
              created_at: character(r, :created_at),
              last_seen: character(r, :last_seen)
            }

          [] ->
            nil
        end
      end)

    res
  end

  defp now, do: System.system_time(:second)
end
