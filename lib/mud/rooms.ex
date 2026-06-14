defmodule Mud.Rooms do
  require Record

  @table :room
  @attrs [:id, :name, :description, :exits]
  Record.defrecord(:room, @attrs)

  def setup do
    case :mnesia.create_table(@table, attributes: @attrs, disc_copies: [node()]) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @table}} -> :ok
      {:aborted, reason} -> raise "Mnesia tabela #{@table}: #{inspect(reason)}"
    end

    :ok = :mnesia.wait_for_tables([@table], 10_000)
  end

  def get(id) do
    case :mnesia.dirty_read(@table, id) do
      [rec] -> to_map(rec)
      [] -> nil
    end
  end

  def persist(room) do
    :mnesia.dirty_write({@table, room.id, room.name, room.description, room.exits})
  end

  def all do
    :mnesia.dirty_all_keys(@table)
    |> Enum.map(&get/1)
  end

  defp to_map(rec) do
    %{
      id: room(rec, :id),
      name: room(rec, :name),
      description: room(rec, :description),
      exits: room(rec, :exits)
    }
  end
end
