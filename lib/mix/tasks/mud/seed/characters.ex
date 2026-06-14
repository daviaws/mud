defmodule Mix.Tasks.Mud.Seed.Characters do
  @moduledoc """
  Gera um arquivo de migration de characters para uma sala.

      mix mud.seed.characters garden.main

  Cria `priv/characters/garden.main/<timestamp>_characters.toml`
  pronto para ser preenchido.
  """
  use Mix.Task

  @shortdoc "Gera um arquivo de migration de characters para uma sala"

  @impl Mix.Task
  def run([room]) do
    timestamp = System.os_time(:second)
    dir = Path.join([File.cwd!(), "priv", "characters"])
    path = Path.join(dir, "#{timestamp}_#{room}.toml")

    File.mkdir_p!(dir)

    File.write!(path, """
    version = #{timestamp}

    [[characters]]
    name = ""
    room = "#{room}"

    [characters.attrs]
    type = ""
    """)

    Mix.shell().info("Migration criada: #{path}")
  end

  def run(_) do
    Mix.shell().error("Uso: mix mud.seed.characters <sala>")
  end
end
