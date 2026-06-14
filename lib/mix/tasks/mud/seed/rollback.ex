defmodule Mix.Tasks.Mud.Seed.Rollback do
  @moduledoc """
  Faz rollback de seed migrations deletando os characters criados.

    mix mud.seed.rollback                              # rollback de todas as migrations, todos os nós
    mix mud.seed.rollback 1781141216                   # versão específica, todos os nós
    mix mud.seed.rollback --dir priv/mnesia/nonode@nohost          # todos os nós, dir específico
    mix mud.seed.rollback 1781141216 --dir priv/mnesia/nonode@nohost

  Lê o arquivo TOML da migration e deleta cada character listado.
  Remove o registro da migration do Mnesia.
  """
  use Mix.Task

  @shortdoc "Rollback the seed migrations"

  require Logger

  @impl Mix.Task
  def run(args) do
    {version, dirs} = parse_args(args)

    Enum.each(dirs, fn dir ->
      Application.put_env(:mnesia, :dir, String.to_charlist(dir))
      :mnesia.start()
      Mud.Characters.setup()
      Mud.Rooms.setup()
      Mud.Seeder.setup()
      Mud.Seeder.rollback(version)
      :mnesia.stop()
      Logger.info("Rollback rodando em #{:mnesia.system_info(:directory)}")
    end)
  end

  defp parse_args(args) do
    {opts, rest, _} = OptionParser.parse(args, strict: [dir: :string])

    version =
      case rest do
        [v] -> String.to_integer(v)
        [] -> :all
      end

    dirs =
      case Keyword.get(opts, :dir) do
        nil ->
          File.cwd!()
          |> Path.join("priv/mnesia/*/")
          |> Path.wildcard()

        path ->
          [path]
      end

    {version, dirs}
  end
end
