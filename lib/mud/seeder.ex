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

  def run do
    File.cwd!()
    |> Path.join("priv/characters/*.toml")
    |> Path.wildcard()
    |> tap(fn files -> Logger.info("Seeder encontrou #{length(files)} arquivo(s)") end)
    |> Enum.each(&run_file/1)
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
