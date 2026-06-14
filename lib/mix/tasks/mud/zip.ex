defmodule Mix.Tasks.Mud.Zip do
  use Mix.Task

  @shortdoc "Zipa o código fonte do projeto em mud.zip"

  def run(_args) do
    root = File.cwd!()
    output = Path.join(root, "mud.zip")

    files =
      Path.wildcard(Path.join(root, "{lib,priv,config,test,docs,assets}/**/*"))
      |> Kernel.++(Path.wildcard(Path.join(root, "{mix.exs,mix.lock,README.md,.tool-versions}")))
      |> Enum.reject(&File.dir?/1)
      |> Enum.reject(&String.contains?(&1, "assets/node_modules/"))
      |> Enum.map(&to_charlist(Path.relative_to(&1, root)))

    :zip.create(to_charlist(output), files, cwd: to_charlist(root))

    Mix.shell().info("Created #{output} with #{length(files)} files")
  end
end
