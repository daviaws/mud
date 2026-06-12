defmodule Mud.Seeder do
  @moduledoc """
  Lê arquivos TOML em `priv/characters/*.toml` e persiste os personagens
  no Mnesia. Idempotente — cada arquivo tem um `version` (timestamp).
  Um seed só é executado se a versão ainda não foi registrada.

  Tabela Mnesia `:seed_migration` guarda `{sala, version}`.
  """
  require Logger
  require Record

  @migration_table :seed_migration
  @migration_attrs [:room, :version]
  Record.defrecord(:seed_migration, @migration_attrs)

  def setup do
    case :mnesia.create_table(@migration_table,
           attributes: @migration_attrs,
           disc_copies: [node()]
         ) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, @migration_table}} -> :ok
      {:aborted, reason} -> raise "Mnesia tabela #{@migration_table}: #{inspect(reason)}"
    end

    :ok = :mnesia.wait_for_tables([@migration_table], 10_000)
  end

  def all_migrations do
    :mnesia.dirty_all_keys(@migration_table)
    |> Enum.map(fn key ->
      [rec] = :mnesia.dirty_read(@migration_table, key)

      %{
        room: seed_migration(rec, :room),
        version: seed_migration(rec, :version)
      }
    end)
  end

  def rollback(version \\ :all) do
    require Logger

    :mnesia.dirty_all_keys(@migration_table)
    |> Enum.each(fn room ->
      [rec] = :mnesia.dirty_read(@migration_table, room)
      ver = seed_migration(rec, :version)

      if version == :all or ver >= version do
        path =
          File.cwd!()
          |> Path.join("priv/characters/#{room}.toml")
          |> Path.wildcard()
          |> List.first()

        if path do
          {:ok, data} = Toml.decode_file(path)

          Enum.map(data["characters"] || [], & &1["name"])
          |> Mud.Characters.delete_many()
        end

        :mnesia.dirty_delete(@migration_table, room)
        Logger.info("Rollback concluído: #{room}")
      end
    end)
  end

  def run(reload \\ true) do
    File.cwd!()
    |> Path.join("priv/characters/*.toml")
    |> Path.wildcard()
    |> tap(fn files -> Logger.info("Seeder encontrou #{length(files)} arquivo(s)") end)
    |> Enum.each(&run_file/1)

    if reload do
      Mud.Characters.PlantSupervisor.reload()
    end

    :ok
  end

  defp run_file(path) do
    {:ok, data} = Toml.decode_file(path)

    room = Path.basename(path, ".toml")
    version = data["version"]

    Logger.info("Seeder processando #{path} -> room=#{room} version=#{version}")

    if already_seeded?(room, version) do
      Logger.info("Seeder já executado: #{room} v#{version}")
      :ok
    else
      seed_characters(data["characters"] || [])
      record_migration(room, version)
      Logger.info("Seeder concluído: #{room} v#{version}")
    end
  end

  defp already_seeded?(room, version) do
    case :mnesia.dirty_read(@migration_table, room) do
      [rec] -> seed_migration(rec, :version) == version
      [] -> false
    end
  end

  defp seed_characters(characters) do
    Enum.each(characters, fn char ->
      attrs =
        (char["attrs"] || %{})
        |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
        |> Map.new()

      Mud.Characters.load_or_create(char["name"], char["room"], attrs)
    end)
  end

  defp record_migration(room, version) do
    :mnesia.dirty_write(seed_migration(room: room, version: version))
  end
end
