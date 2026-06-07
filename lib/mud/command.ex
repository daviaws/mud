defmodule Mud.Command do
  @moduledoc "Parser bobo de linha → comando. Cresça-o à vontade."

  @directions ~w(norte sul leste oeste)

  def parse(""), do: :empty

  def parse(line) do
    case String.split(line, " ", parts: 2) do
      [c] when c in ~w(look l olhar) -> :look
      [c] when c in ~w(quit sair) -> :quit
      [dir] when dir in @directions -> {:move, dir}
      ["say", text] -> {:say, text}
      ["dizer", text] -> {:say, text}
      ["go", dir] -> {:move, dir}
      ["ir", dir] -> {:move, dir}
      _ -> :unknown
    end
  end
end
