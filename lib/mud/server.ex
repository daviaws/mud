defmodule Mud.Server do
  @moduledoc """
  Um processo por conexão telnet. Mantém o estado do jogador e traduz
  bytes do socket em comandos. Mensagens vindas das salas chegam como
  `{:tell, msg}` em `handle_info/2`.
  """
  use ThousandIsland.Handler

  alias ThousandIsland.Socket

  @impl ThousandIsland.Handler
  def handle_connection(socket, _state) do
    Socket.send(socket, "Bem-vindo ao mundo.\r\nQual é o seu nome? ")
    {:continue, %{stage: :login, name: nil, room: nil, buffer: ""}}
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
        room = resolve_room(Mud.Characters.load_or_create(name, Mud.World.start_room()))
        desc = Mud.Room.enter(room, name)
        Socket.send(socket, "\r\n" <> desc)
        %{state | stage: :playing, name: name, room: room}
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
  defp resolve_room(room) do
    case Registry.lookup(Mud.RoomRegistry, room) do
      [_ | _] -> room
      [] -> Mud.World.start_room()
    end
  end

  ## Helpers

  # Telnet manda linhas terminadas em CRLF. Acumulamos parciais no buffer.
  defp extract_lines(data) do
    parts = String.split(data, "\n")
    {complete, [rest]} = Enum.split(parts, -1)
    lines = Enum.map(complete, &String.trim_trailing(&1, "\r"))
    {lines, rest}
  end

  defp prompt(%{stage: :playing}), do: "\r\n> "
  defp prompt(_), do: ""
end
