defmodule Mud.Commands.Command do
  @moduledoc """
  Contrato de um comando. Cada comando vive no seu próprio módulo em
  `Mud.Commands.*`, declara os nomes pelos quais é invocado e sabe se
  executar sobre a sessão do jogador.

  `run/3` recebe o verbo que casou (útil pra comandos como mover, cujo
  próprio nome é a direção), os argumentos crus (resto da linha) e a
  sessão; devolve `{sessão_nova, saída | nil}`. Nunca toca no socket —
  isso é responsabilidade do transporte (`Mud.Server`).

  A sessão é um mapa com pelo menos:
    - `character` — `%Mud.Character{}`
    - `stage`     — `:playing`
  """

  @type session :: %{
          required(:character) => Mud.Character.t(),
          required(:stage) => :playing,
          optional(atom()) => any()
        }

  @callback names() :: [String.t()]
  @callback run(verb :: String.t(), args :: String.t(), session()) ::
              {session(), output :: String.t() | nil}
end
