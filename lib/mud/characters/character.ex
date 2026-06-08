defmodule Mud.Characters.Character do
  @moduledoc """
  Estado do personagem em memória durante uma sessão ativa.
  Carregado do Mnesia no login, persistido de volta em eventos relevantes.
  Não é um GenServer — é uma struct pura.
  """

  defstruct [:name, :room, attrs: %{}]

  @type t :: %__MODULE__{
          name: String.t(),
          room: atom(),
          attrs: map()
        }

  @doc "Constrói um Character a partir do que o Mud.Characters.load_or_create retorna."
  def from_session(name, room) do
    %__MODULE__{name: name, room: room}
  end
end
