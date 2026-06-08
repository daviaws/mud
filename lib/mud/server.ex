defmodule Mud.Server do
  @moduledoc """
  Um processo por conexão telnet. Mantém o estado da sessão e traduz
  bytes do socket em comandos. Mensagens vindas das salas chegam como
  `{:tell, msg}` em `handle_info/2`.

  Estado da sessão:
    - `stage`     — `:login | :playing | :closing`
    - `buffer`    — bytes parciais ainda não processados
    - `character` — `%Mud.Character{}` quando `:playing`, `nil` no login
  """
  use ThousandIsland.Handler

  alias ThousandIsland.Socket

  @impl ThousandIsland.Handler
  def handle_connection(socket, _state) do
    Socket.send(socket, "Bem-vindo ao mundo.\r\nQual é o seu nome? ")
    {:continue, %{stage: :login, buffer: "", character: nil}}
  end

  @impl ThousandIsland.Handler
  def handle_data(data, socket, state) do
    {lines, buffer} = extract_lines(state.buffer <> data)

    state =
      Enum.reduce(lines, %{state | buffer: buffer}, fn line, acc ->
        handle_line(String.trim(line), socket, acc)
      end)

    if lines != [] and state.stage == :playing do
      Socket.send(socket, prompt(state))
    end

    {:continue, state}
  end

  # Broadcast de uma sala. ThousandIsland entrega `{socket, state}`.
  @impl GenServer
  def handle_info({:tell, message}, {socket, state}) do
    Socket.send(socket, "\r\n" <> message <> prompt(state))
    {:noreply, {socket, state}}
  end

  ## Linha de input

  defp handle_line(name, socket, %{stage: :login} = state) do
    case String.trim(name) do
      "" ->
        Socket.send(socket, "Nome inválido. Qual é o seu nome? ")
        state

      name ->
        character =
          name
          |> Mud.Characters.load_or_create(Mud.World.start_room())
          |> resolve_room()

        desc = Mud.Room.enter(character.room, character.name)
        Socket.send(socket, "\r\n" <> desc)
        %{state | stage: :playing, character: character}
    end
  end

  defp handle_line(line, socket, %{stage: :playing} = state) do
    {state, output} = Mud.Commands.dispatch(line, state)
    if output, do: Socket.send(socket, output)

    if state[:quit?] do
      Socket.close(socket)
      %{state | stage: :closing}
    else
      state
    end
  end

  # Se a sala salva não existe mais (renomeada/removida), cai na sala inicial.
  defp resolve_room(%Mud.Characters.Character{room: room} = character) do
    case Registry.lookup(Mud.RoomRegistry, room) do
      [_ | _] -> character
      [] -> %{character | room: Mud.World.start_room()}
    end
  end

  ## Helpers

  defp extract_lines(data) do
    parts = String.split(data, "\n")
    {complete, [rest]} = Enum.split(parts, -1)
    lines = Enum.map(complete, &String.trim_trailing(&1, "\r"))
    {lines, rest}
  end

  defp prompt(%{stage: :playing}), do: "\r\n> "
  defp prompt(_), do: ""
end
