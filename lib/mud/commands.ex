defmodule Mud.Commands do
  @moduledoc """
  Despacho de comandos. Cada arquivo em `lib/mud/command/` vira um
  módulo `Mud.Commands.<Nome>` e é descoberto em tempo de compilação —
  a tabela `nome -> módulo` é montada uma única vez, aqui, e embutida no
  bytecode. Custo em runtime: zero.

  Para adicionar um comando, crie o arquivo em `lib/mud/command/`.
  Como a descoberta é em compile-time, um arquivo *novo* só entra quando
  este módulo recompila — em dev: `touch lib/mud/command.ex` seguido de
  `recompile()` (editar um comando existente já dispara, via
  `@external_resource`).
  """

  require Logger

  command_files = Path.wildcard(Path.join(__DIR__, "command/*"))

  Logger.info("Command __DIR__: #{__DIR__}")
  for path <- command_files, do: Logger.info(path)

  # Recompila este módulo quando qualquer arquivo de comando muda.
  for path <- command_files, do: @external_resource path

  @table (for path <- command_files,
              mod = Module.concat([Mud.Commands, Macro.camelize(Path.basename(path, ".ex"))]),
              _ = Code.ensure_compiled!(mod),
              _ = Code.ensure_loaded!(mod),
              function_exported?(mod, :names, 0),
              name <- mod.names(),
              into: %{} do
            {name, mod}
          end)

  @verbs @table |> Map.keys() |> Enum.sort() |> Enum.join(", ")

  def dispatch("", session), do: {session, nil}

  def dispatch(line, session) do
    {verb, args} = split(line)

    case Map.fetch(@table, verb) do
      {:ok, mod} -> mod.run(verb, args, session)
      :error -> {session, "Não entendi. Tente: #{@verbs}.\r\n"}
    end
  end

  defp split(line) do
    case String.split(line, " ", parts: 2) do
      [v] -> {v, ""}
      [v, rest] -> {v, rest}
    end
  end
end
